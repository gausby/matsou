defmodule Matsou.Schema do
  defmacro __using__(_) do
    quote do
      import Matsou.Schema, only: [schema: 2]
    end
  end

  defmacro schema(bucket, [do: block]) do
    quote do
      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :matsou_fields, accumulate: true)

      bucket = unquote(bucket)
      bucket_type = Module.get_attribute(__MODULE__, :bucket_type) || "default"

      try do
        import Matsou.Schema
        unquote(block)
      after
        :ok
      end

      Module.eval_quoted __ENV__, [
        Matsou.Schema.__defstruct__(@struct_fields),
        Matsou.Schema.__schema__(bucket_type, bucket)
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
  def __field__(mod, name, type, _opts) do
    put_struct_field(mod, name)

    Module.put_attribute(mod, :matsou_fields, {name, type})
  end

  @doc false
  def __defstruct__(struct_fields) do
    quote do
      defstruct unquote(Macro.escape(struct_fields))
    end
  end

  defp put_struct_field(mod, name) do
    fields = Module.get_attribute(mod, :struct_fields)

    case name in fields do
      true ->
        raise ArgumentError, "Field already #{inspect name} set on schema"

      _ ->
        Module.put_attribute(mod, :struct_fields, name)
    end
  end

  def __schema__(bucket_type, bucket) do
    quote do
      def __schema__(:bucket), do: unquote(bucket)
      def __schema__(:type), do: unquote(bucket_type)
    end
  end
end
