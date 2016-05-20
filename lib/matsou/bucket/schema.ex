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

    changeset
    |> put_bucket_and_action(:insert, bucket)
    |> surface_changes(struct, types, fields)
    |> build_crdt(fields)
  end
  defp do_insert(_repo, %Changeset{valid?: false} = _changeset, _opts) do
    {:error, "invalid changeset"}
  end

  # build
  defp build_crdt(%Changeset{action: :insert} = changeset, fields) do
    # build the CRDT here
    changeset
  end

  # helpers
  defp put_bucket_and_action(changeset, action, bucket) do
    %Changeset{changeset | action: action, bucket: bucket}
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
