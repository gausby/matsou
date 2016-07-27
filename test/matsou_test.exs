defmodule MatsouTest do
  use ExUnit.Case
  doctest Matsou

  alias Matsou.Changeset

  describe "registers" do
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

    test "insert, find, change, update, and delete a register" do
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
  end

  describe "flags" do
    defmodule FlagBucket do
      use Matsou.Bucket
    end

    defmodule Flag do
      use Matsou.Schema
      @bucket "user"

      schema "flag" do
        field :name, :register
        field :voted, :flag, default: false
      end
    end

    test "insert, get, change, and update a flag" do
      # insert a flag
      flag =
        %Flag{}
        |> Matsou.Changeset.change(voted: true, name: "John Doe")
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
      assert flag.name == "John Doe"

      # delete the flag
      assert %Matsou.Changeset{action: :delete} = FlagBucket.delete(flag)
      assert Matsou.Bucket.get(Flag, generated_key) == nil
    end

    test "initialization of a flag in disabled default state" do
      # insert a flag with default values (disabled)
      flag = FlagBucket.insert(%Flag{})
      generated_key = flag.data.__meta__.key
      refute flag.data.voted

      update =
        Matsou.Bucket.get(Flag, generated_key)
        |> Matsou.Changeset.change(voted: true)
        |> FlagBucket.update
      assert update.data.voted

      update =
        Matsou.Bucket.get(Flag, generated_key)
        |> Matsou.Changeset.change(voted: false)
        |> FlagBucket.update
      refute update.data.voted

      # delete the flag
      assert %Matsou.Changeset{action: :delete} = FlagBucket.delete(flag)
      assert Matsou.Bucket.get(Flag, generated_key) == nil
    end
  end

  describe "Sets" do
    defmodule SetBucket do
      use Matsou.Bucket
    end

    defmodule Set do
      use Matsou.Schema
      @bucket "user"

      schema "set" do
        field :interests, :set
      end
    end

    test "create, insert, and get a set" do
      # insert a set
      set =
        %Set{}
        |> Matsou.Changeset.change(interests: MapSet.new(["foo", "bar"]))
        |> SetBucket.insert

      assert %Matsou.Changeset{action: :insert} = set
      generated_key = set.data.__meta__.key

      # get the set
      set = Matsou.Bucket.get(Set, generated_key)
      expected_set = MapSet.new(["foo", "bar"])
      assert %Set{interests: ^expected_set} = set

      # change data and update
      change =
        set
        |> Changeset.change(interests: fn interests ->
             interests |> MapSet.put("baz") |> MapSet.delete("bar")
           end)
        |> SetBucket.update

      expected_set = MapSet.new(["foo", "baz"])
      assert %Changeset{action: :update, data: %{interests: ^expected_set}} = change

      # get the set again
      set = Matsou.Bucket.get(Set, generated_key)
      assert %Set{interests: ^expected_set} = set

      assert %Matsou.Changeset{action: :delete} = SetBucket.delete(set)
      assert Matsou.Bucket.get(Set, generated_key) == nil
    end
  end

  describe "Counters" do
    defmodule CounterBucket do
      use Matsou.Bucket
    end

    defmodule Counter do
      use Matsou.Schema
      @bucket "user"

      schema "counter" do
        field :visits, :counter
      end
    end

    test "create, insert, and get a counter" do
      # insert a counter
      counter =
        %Counter{}
        |> Matsou.Changeset.change(visits: 1)
        |> CounterBucket.insert

      assert %Matsou.Changeset{action: :insert} = counter
      generated_key = counter.data.__meta__.key

      # get the counter
      counter = Matsou.Bucket.get(Counter, generated_key)
      assert %Counter{visits: 1} = counter

      # change data and update
      change =
        counter
        |> Changeset.change(visits: fn visits -> visits + 41 end)
        |> CounterBucket.update

      assert %Changeset{action: :update, data: %{visits: 42}} = change

      # get the counter again
      counter = Matsou.Bucket.get(Counter, generated_key)
      assert %Counter{visits: 42} = counter

      assert %Matsou.Changeset{action: :delete} = CounterBucket.delete(counter)
      assert Matsou.Bucket.get(Counter, generated_key) == nil
    end
  end
end
