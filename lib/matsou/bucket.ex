defmodule Matsou.Bucket do
  # reference Ecto.Repo

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do

      def insert(struct, opts \\ []) do
        Matsou.Bucket.Schema.insert(__MODULE__, struct, opts)
      end

      def update(struct, opts \\ []) do
        Matsou.Bucket.Schema.update(__MODULE__, struct, opts)
      end

      def delete(struct, opts \\ []) do
        Matsou.Bucket.Schema.delete(__MODULE__, struct, opts)
      end
    end
  end

  def get(struct, id, _opts \\ []) when is_atom(struct) do
    bucket_name = struct.__schema__(:bucket)
    bucket_type = struct.__schema__(:type)

    case Riak.find(bucket_name, bucket_type, id) do
      nil ->
        nil

      data ->
        data
        |> into_structure(struct)
        |> Matsou.put_meta(key: id, raw: data)
    end
  end

  defp into_structure(data, struct) do
    {:map, data, _, _, _} = data
    data = data |> Enum.map(&type/1) |> Enum.into(%{})
    struct(struct, data)
  end

  defp type({{key, :register}, value}) do
    {String.to_atom(key), value}
  end
  defp type(value) do
    value
  end
end
