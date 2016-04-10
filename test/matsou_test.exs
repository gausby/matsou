defmodule MatsouTest do
  use ExUnit.Case
  doctest Matsou

  defmodule MyModule do
    use Matsou
  end

  test "the truth" do
    assert 1 + 1 == 2
  end
end
