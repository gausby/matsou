defmodule MatsouTest do
  use ExUnit.Case
  doctest Matsou

  alias Matsou.Changeset

  defmodule UserBucket do
    use Matsou.Bucket
  end

  defmodule User do
    use Matsou.Schema

    @bucket "user"

    schema "profile" do
      field :name, :register
      field :email, :register, default: "john.doe@example.com"
    end
  end

  test "Should be able to get from a repo" do
    %User{}
    |> Matsou.Changeset.change(name: "martin")
    |> UserBucket.insert

    assert %User{name: "martin"} = Matsou.Bucket.get(User, "test")
  end

  test "Should be able to insert, find, change, and delete" do
    # insert a user
    user =
      %User{}
      |> Matsou.Changeset.change(name: "hello")
      |> UserBucket.insert
    assert %Matsou.Changeset{action: :insert} = user
    # get the user
    user = Matsou.Bucket.get(User, "test")
    assert %User{email: "john.doe@example.com"} = user
    # change data
    change =
      user
      |> Changeset.change(email: "foo@example.com")
      |> UserBucket.update
    assert %Changeset{action: :update, data: %{email: "foo@example.com"}} = change
    # delete user
    assert %Matsou.Changeset{action: :delete} = UserBucket.delete(user)
    assert Matsou.Bucket.get(User, "test") == nil
  end
end
