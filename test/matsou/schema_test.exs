defmodule Matsou.SchemaTest do
  use ExUnit.Case
  doctest Matsou.Schema

  defmodule MyModule do
    use Matsou.Schema

    schema "default" do
      field :name, :register
      field :age, :counter
      field :interests, :set
    end
  end

  defmodule MyModuleWithBucketType do
    use Matsou.Schema
    @bucket "user"
    schema "foo" do
      field :name, :register
      field :age, :counter
      field :interests, :set
    end
  end

  test "should return a struct" do
    assert Map.has_key? %MyModule{}, :name
    assert Map.has_key? %MyModule{}, :age
    assert Map.has_key? %MyModule{}, :interests
  end

  test "should have a db key assigned to nil by default" do
    # pending
  end

  test "should set bucket type to default if none is specified" do
    assert MyModule.__schema__(:type) == "default"
  end

  test "a bucket type should be specifiable" do
    assert MyModuleWithBucketType.__schema__(:type) == "foo"
  end

  test "bucket keys should have types" do
    assert MyModuleWithBucketType.__schema__(:types) ==
      %{name: :register,
        age: :counter,
        interests: :set}
    assert MyModuleWithBucketType.__schema__(:type, :name) == :register
    assert MyModuleWithBucketType.__schema__(:type, :age) == :counter
    assert MyModuleWithBucketType.__schema__(:type, :interests) == :set
  end

  defmodule MyModuleWithCustomDefaultKeyRepo do
    use Matsou.Bucket
  end

  defmodule MyModuleWithCustomDefaultKey do
    use Matsou.Schema
    @bucket "user"
    schema "foo" do
      field :name, :register
      field :age, :counter
    end

    def generate_key(changeset) do
      changeset.changes.name
    end
  end

  test "the default key should be customizable" do
    user =
      %MyModuleWithCustomDefaultKey{}
      |> Matsou.Changeset.change(name: "bar")
      |> MyModuleWithCustomDefaultKeyRepo.insert

    assert user.data.__meta__.key == "bar"
    Riak.delete("user", "foo", "bar")
  end

  test "the default key should not be run if the key is already set" do
    my_key = "my-key"
    user =
      %MyModuleWithCustomDefaultKey{}
      |> Matsou.put_meta(key: my_key)
      |> Matsou.Changeset.change(name: "bar")
      |> MyModuleWithCustomDefaultKeyRepo.insert

    refute user.data.__meta__.key == "bar"
    Riak.delete("user", "foo", my_key)
  end
end
