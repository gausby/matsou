defmodule Matsou do
  @moduledoc """
  An Elixir wrapper around Riak CRDT types.
  """

  # should work as plug, a pipeline where operations can be done
  # should fail if a value that isn't in the schema is set
  # should fail if a dirty value fail to validate

  # counters, should be able to set, increment, or decrement value probably with a fn old -> new end
end
