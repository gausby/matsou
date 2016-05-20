defmodule Matsou.Schema do
  defmacro __using__(_) do
    quote do
      import Matsou.Schema, only: [schema: 2]
    end
  end

  defmacro schema(bucket_type, [do: block]) do
    quote do
      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :changeset_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :matsou_fields, accumulate: true)

      bucket_type = unquote(bucket_type)
      bucket = Module.get_attribute(__MODULE__, :bucket)

      try do
        import Matsou.Schema
        unquote(block)
      after
        :ok
      end

      fields = @matsou_fields |> Enum.reverse

      Module.eval_quoted __ENV__, [
        Matsou.Schema.__defstruct__(@struct_fields),
        Matsou.Schema.__changeset__(@changeset_fields),
        Matsou.Schema.__schema__(bucket_type, bucket, fields),
        Matsou.Schema.__types__(fields)
      ]
    end
  end

  # struct_fields - the stuff that ends up in the struct
  # matsou_fields - the stuff that should get saved to the database

  defmacro field(name, type \\ :register, opts \\ []) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      Matsou.Schema.__field__(__MODULE__, name, type, opts)
    end
  end

  @doc false
  def __field__(mod, name, type, opts) do
    Module.put_attribute(mod, :changeset_fields, {name, type})
    default = Keyword.get(opts, :default)
    put_struct_field(mod, name, default)

    # this will become important when we get into virtual fields
    Module.put_attribute(mod, :matsou_fields, {name, type})
  end

  @doc false
  def __changeset__(changeset_fields) do
    map = changeset_fields |> Enum.into(%{}) |> Macro.escape()
    quote do
      def __changeset__, do: unquote(map)
    end
  end

  @doc false
  def __defstruct__(struct_fields) do
    quote do
      defstruct unquote(Macro.escape(struct_fields))
    end
  end

  defp put_struct_field(mod, key, default) do
    fields = Module.get_attribute(mod, :struct_fields)

    case key in fields do
      true ->
        raise ArgumentError, "Field already #{inspect key} set on schema"

      _ ->
        Module.put_attribute(mod, :struct_fields, {key, default})
    end
  end

  def __schema__(bucket_type, bucket, fields) do
    field_names = Enum.map(fields, &elem(&1, 0))
    quote do
      def __schema__(:query), do: %Matsou.Query{from: {unquote(bucket_type), __MODULE__}}
      def __schema__(:bucket), do: unquote(bucket)
      def __schema__(:type), do: unquote(bucket_type)
      def __schema__(:fields), do: unquote(field_names)
    end
  end

  @doc false
  def __types__(fields) do
    quoted =
      Enum.map(fields, fn {name, type} ->
        quote do
          def __schema__(:type, unquote(name)) do
            unquote(Macro.escape(type))
          end
        end
      end)

    types = Macro.escape(Map.new(fields))
    quote do
      def __schema__(:types) do
        unquote(types)
      end
      unquote(quoted)
      def __schema__(:type, _) do
        nil
      end
    end
  end
end
