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

    key = "test" # todo!

    changeset =
      changeset
      |> put_action(:insert)
      |> put_bucket_and_type(bucket, type)
      |> surface_changes(struct, types, fields)
      |> build_crdt

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
          register = CRDT.Register.new(value)
          CRDT.Map.put(acc, key, register)
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
