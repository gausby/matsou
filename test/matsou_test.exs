defmodule MatsouTest do
  use ExUnit.Case
  doctest Matsou

  defmodule UserBucket do
    use Matsou.Bucket
  end

  defmodule User do
    use Matsou.Schema

    @bucket "user"

    schema "profile" do
      field :name, :register
      field :email, :register, default: "hello@example.com"
    end
  end

  test "Should be able to get from a repo" do
    assert %User{name: "martin"} = Matsou.Bucket.get(User, "1")
  end

  test "Should be able to get entry key" do
    result =
      %User{}
      |> Matsou.Changeset.change(name: "martin")
      # |> Matsou.Changeset.validate_change(:name, fn
      #      :name, "martin" ->
      #        []

      #      :name, _ ->
      #        [name: "oh, my!"]
      #    end)
      |> UserBucket.insert

    IO.inspect result
  end
end
