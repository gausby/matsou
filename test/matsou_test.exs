defmodule MatsouTest do
  use ExUnit.Case
  doctest Matsou

  defmodule User do
    use Matsou.Schema

    @bucket "user"

    schema "profile" do
      field :name, :register
      field :email, :register
    end
  end

  test "Should be able to get from a repo" do
    IO.inspect Matsou.Bucket.get(User, "1")
  end
end
