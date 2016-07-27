defmodule Matsou.Bucket.Schema do
  alias Matsou.Changeset
  alias Riak.CRDT

  def insert(repo, %Changeset{} = changeset, opts) do
    do_insert(repo, changeset, opts)
  end
  def insert(repo, %{__struct__: _} = struct, opts) do
    changeset = Changeset.change(struct)
    do_insert(repo, changeset, opts)
  end

  defp do_insert(_repo, %Changeset{valid?: true, types: types} = changeset, _opts) do
    struct = struct_from_changeset!(changeset)
    schema = struct.__struct__
    fields = schema.__schema__(:fields)
    bucket = schema.__schema__(:bucket)
    type = schema.__schema__(:type)

    changeset =
      changeset
      |> put_action(:insert)
      |> put_bucket_and_type(bucket, type)
      |> surface_changes(struct, types, fields)
      |> build_crdt

    key =
      unless changeset.data.__meta__.key do
        schema.generate_key(changeset)
      else
        changeset.data.__meta__.key
      end

    unless is_binary(key) do
      raise ArgumentError, "key should be a binary got #{inspect key}"
    end

    case Riak.update(changeset.data.__meta__.raw, bucket, type, key) do
      :ok ->
        changeset = put_in(changeset.data, Map.merge(changeset.data, changeset.changes))
        changeset = put_in(changeset.data.__meta__.state, :built)
        put_in(changeset.data.__meta__.key, key)

      {:error, _} = error ->
        error
    end
  end
  defp do_insert(_repo, %Changeset{valid?: false} = _changeset, _opts) do
    {:error, "invalid changeset"}
  end

  defp build_crdt(%Changeset{action: :insert, data: %{__meta__: %{raw: nil}}} = changeset) do
    data = Enum.reduce(changeset.changes, CRDT.Map.new(), fn {key, value}, acc ->
      case {Map.get(changeset.types, key), to_string(key)} do
        {:register, key} ->
          register = CRDT.Register.new(value)
          CRDT.Map.put(acc, key, register)

        {:counter, key} ->
          counter = CRDT.Counter.new()
          CRDT.Map.put(acc, key, CRDT.Counter.increment(counter, value))

        {:set, key} ->
          set =
            Enum.reduce(MapSet.to_list(value), CRDT.Set.new(), fn(item, acc) ->
              CRDT.Set.put(acc, item)
            end)
          CRDT.Map.put(acc, key, set)

        {:flag, key} ->
          case value do
            true ->
              acc
              |> CRDT.Map.put(key, CRDT.Flag.new(key))
              |> CRDT.Map.update(:flag, key, &CRDT.Flag.enable/1)

            _ ->
              acc
              |> CRDT.Map.put(key, CRDT.Flag.new(key))
              |> CRDT.Map.update(:flag, key, &CRDT.Flag.disable/1)
          end
      end
    end)

    put_in(changeset.data.__meta__.raw, data)
  end

  @doc """
  Update
  """
  def update(repo, %Changeset{} = changeset, opts) do
    do_update(repo, changeset, opts)
  end

  defp do_update(_repo, %Changeset{data: %{__meta__: %{key: key}}} = changeset, _opts) when key != nil do
    struct = struct_from_changeset!(changeset)
    schema = struct.__struct__
    bucket = schema.__schema__(:bucket)
    type = schema.__schema__(:type)

    changeset =
      changeset
      |> put_action(:update)
      |> put_bucket_and_type(bucket, type)
      |> update_crdt

    case Riak.update(changeset.data.__meta__.raw, bucket, type, key) do
      :ok ->
        changeset = put_in(changeset.data, Map.merge(changeset.data, changeset.changes))
        put_in(changeset.data.__meta__.state, :built)

      {:error, _} = error ->
        error
    end
  end

  defp update_crdt(%Changeset{action: :update, data: %{__meta__: %{raw: crdt}}} = changeset) do
    update = Enum.reduce(changeset.changes, crdt, fn {key, value}, acc ->
      case {Map.get(changeset.types, key), to_string(key)} do
        {:register, key} ->
          CRDT.Map.update(acc, :register, key, &(CRDT.Register.set(&1, value)))

        {:counter, key} ->
          CRDT.Map.update(acc, :counter, key, fn counter ->
            current = CRDT.Counter.value(counter)
            CRDT.Counter.increment(counter, value - current)
          end)

        {:set, key} ->
          CRDT.Map.update(acc, :set, key, fn current ->
            current_value = MapSet.new(CRDT.Set.value(current))
            deletes = MapSet.difference(current_value, value)
            inserts = MapSet.difference(value, current_value)

            current = Enum.reduce(deletes, current, &(CRDT.Set.delete(&2, &1)))
            Enum.reduce(inserts, current, &(CRDT.Set.put(&2, &1)))
          end)

        {:flag, key} ->
          flag = CRDT.Flag.new
          case value do
            true ->
              CRDT.Map.update(acc, :flag, key, &CRDT.Flag.enable/1)

            _ ->
              CRDT.Map.update(acc, :flag, key, &CRDT.Flag.disable/1)
          end
      end
    end)

    put_in(changeset.data.__meta__.raw, update)
  end

  @doc """
  Delete
  """
  def delete(repo, %Changeset{} = changeset, opts) do
    do_delete(repo, changeset, opts)
  end
  def delete(repo, %{__struct__: _} = struct, opts) when is_list(opts) do
    changeset =  Matsou.Changeset.change(struct)
    do_delete(repo, changeset, opts)
  end

  defp do_delete(_repo, %Changeset{valid?: true,
                                   data: %{__meta__: %{key: key}}} = changeset, _opts)
  when key != nil do
    struct = struct_from_changeset!(changeset)
    schema = struct.__struct__
    bucket = schema.__schema__(:bucket)
    type = schema.__schema__(:type)

    changeset =
      changeset
      |> put_action(:delete)
      |> put_bucket_and_type(bucket, type)

    changeset = %Changeset{changeset|changes: %{}}

    case Riak.delete(bucket, type, key) do
      :ok ->
        put_in(changeset.data.__meta__.state, :deleted)

      {:error, _} = error ->
        error
    end
  end
  defp do_delete(_repo, %Changeset{valid?: false} = changeset, _opts) do
    struct = struct_from_changeset!(changeset)
    schema = struct.__struct__
    bucket = schema.__schema__(:bucket)
    bucket_type = schema.__schema__(:type)

    changeset =
      changeset
      |> put_action(:delete)
      |> put_bucket_and_type(bucket, bucket_type)

    {:error, changeset}
  end

  # helpers
  defp put_action(changeset, action) do
    %Changeset{changeset | action: action}
  end
  defp put_bucket_and_type(changeset, bucket, bucket_type) do
    %Changeset{changeset|bucket: bucket, type: bucket_type}
  end

  # go through all the fields and add the ones with default values
  # to the change set if they are not set.
  defp surface_changes(%Changeset{changes: changes} = changeset, struct, types, fields) do
    changes =
      Enum.reduce(fields, changes, fn(field, changes) ->
        case {struct, changes, types} do
          # user has set this value, keep it
          {_, %{^field => _},_} ->
            changes

          # user didn't the change value, keep the default
          {%{^field => default_value}, _, %{^field => _}} when default_value != nil ->
            Map.put(changes, field, default_value)

          # just ignore this one
          {_, _, _} ->
            changes
        end
      end)

    %Changeset{changeset|changes: changes}
  end

  defp struct_from_changeset!(%Changeset{data: nil}) do
    raise(ArgumentError, "cannot insert a changeset without :data")
  end
  defp struct_from_changeset!(%Changeset{data: struct}) do
    struct
  end
end
