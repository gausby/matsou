defmodule Matsou.Bucket do
  # reference Ecto.Repo

  def get(struct, id, _opts \\ []) when is_atom(struct) do
    bucket_name = struct.__schema__(:bucket)
    bucket_type = struct.__schema__(:type)

    case Riak.find(bucket_name, bucket_type, id) do
      nil ->
        nil

      data ->
        data |> into_structure(struct)
    end
  end

  defp into_structure(data, struct) do
    test = struct(struct)
    {:map, data, _, _, _} = data

    data = data |> Enum.map(&foo/1) |> Enum.into(%{})
    struct(struct, data)
  end

  defp foo({{key, :register}, value}) do
    {String.to_atom(key), value}
  end
  defp foo(value) do
    value
  end
end
