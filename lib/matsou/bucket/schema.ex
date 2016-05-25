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
    bucket_type = schema.__schema__(:type)

    changeset
    |> put_action(:insert)
    |> put_bucket_and_type(bucket, bucket_type)
    |> surface_changes(struct, types, fields)
    |> build_crdt(fields)
  end
  defp do_insert(_repo, %Changeset{valid?: false} = _changeset, _opts) do
    {:error, "invalid changeset"}
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

  defp do_delete(repo, %Changeset{valid?: true,
                                  data: %{__meta__: %{key: key}}} = changeset, opts)
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
  defp do_delete(repo, %Changeset{valid?: false} = changeset, opts) do
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

  # build
  defp build_crdt(%Changeset{action: :insert} = changeset, fields) do
    # build the CRDT here
    Enum.reduce(changeset.changes, CRDT.Map.new(), fn {key, value}, acc ->
      case {Map.get(changeset.types, key), to_string(key)} do
        {:register, key} ->
          register = CRDT.Register.new(value)
          CRDT.Map.put(acc, key, register)
      end
    end)
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
