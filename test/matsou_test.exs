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
    user =
      %User{}
      |> Matsou.Changeset.change(name: "martin")
      |> UserBucket.insert

    generated_key = user.data.__meta__.key

    assert %User{name: "martin"} = Matsou.Bucket.get(User, generated_key)
  end

  test "Should be able to insert, find, change, and delete" do
    # insert a user
    user =
      %User{}
      |> Matsou.Changeset.change(name: "hello")
      |> UserBucket.insert
    assert %Matsou.Changeset{action: :insert} = user

    generated_key = user.data.__meta__.key

    # get the user
    user = Matsou.Bucket.get(User, generated_key)
    assert %User{email: "john.doe@example.com"} = user

    # change data
    change =
      user
      |> Changeset.change(email: "foo@example.com")
      |> UserBucket.update
    assert %Changeset{action: :update, data: %{email: "foo@example.com"}} = change

    # delete user
    assert %Matsou.Changeset{action: :delete} = UserBucket.delete(user)
    assert Matsou.Bucket.get(User, generated_key) == nil
  end


  defmodule FlagBucket do
    use Matsou.Bucket
  end

  defmodule Flag do
    use Matsou.Schema
    @bucket "user"

    schema "flag" do
      field :voted, :flag
    end
  end

  test "flag" do
    # insert a flag
    flag =
      %Flag{}
      |> Matsou.Changeset.change(voted: true)
      |> FlagBucket.insert

    assert %Matsou.Changeset{action: :insert} = flag

    generated_key = flag.data.__meta__.key

    # get the flag
    flag = Matsou.Bucket.get(Flag, generated_key)
    assert %Flag{voted: true} = flag

    # change data
    change =
      flag
      |> Changeset.change(voted: false)
      |> FlagBucket.update
    assert %Changeset{action: :update, data: %{voted: false}} = change

    # get the flag again
    flag = Matsou.Bucket.get(Flag, generated_key)
    assert %Flag{voted: false} = flag

    # delete the flag
    assert %Matsou.Changeset{action: :delete} = FlagBucket.delete(flag)
    assert Matsou.Bucket.get(Flag, generated_key) == nil
  end
end
