defmodule Matsou.Bucket.Schema do
  alias Matsou.Changeset

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

    put_bucket_and_action(changeset, :insert, bucket)
  end
  defp do_insert(_repo, %Changeset{valid?: false} = _changeset, _opts) do
    {:error, "invalid changeset"}
  end

  # helpers
  defp put_bucket_and_action(changeset, action, bucket) do
    %Changeset{changeset | action: action, bucket: bucket}
  end

  defp struct_from_changeset!(%Changeset{data: nil}) do
    raise(ArgumentError, "cannot insert a changeset without :data")
  end
  defp struct_from_changeset!(%Changeset{data: struct}) do
    struct
  end
end
