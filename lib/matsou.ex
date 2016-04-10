defmodule Matsou do
  @moduledoc """
  An Elixir wrapper around Riak CRDT types.
  """

  # should work as plug, a pipeline where operations can be done
  # should fail if a value that isn't in the schema is set
  # should fail if a dirty value fail to validate

  # counters, should be able to set, increment, or decrement value probably with a fn old -> new end

  defmacro __using__(_) do
    quote do
      import Matsou, only: [valid?: 1]
    end
  end

  def valid?(struct) do
    struct
  end
end

defmodule Matsou.Struct do
  @moduledoc """
  A struct that hold the data to convert a value to a Riak CRDT
  """
  defstruct(
    data: nil,
    type: nil,
    dirty: [],
    valid?: false
  )

  @type type_identifier :: :counter | :map | :register | :flag | nil
end
