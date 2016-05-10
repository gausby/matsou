defmodule Matsou.SchemaTest do
  use ExUnit.Case
  doctest Matsou.Schema

  defmodule MyModule do
    use Matsou.Schema

    schema "default" do
      field :name, :register
      field :age, :counter
    end
  end

  defmodule MyModuleWithBucketType do
    use Matsou.Schema
    @bucket "user"
    schema "foo" do
      field :name, :register
      field :age, :counter
    end
  end

  test "should return a struct" do
    assert Map.has_key? %MyModule{}, :name
    assert Map.has_key? %MyModule{}, :age
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

  test "a bucket type should " do
    assert MyModuleWithBucketType.__schema__(:types) == %{name: :register, age: :counter}
    assert MyModuleWithBucketType.__schema__(:type, :name) == :register
  end

end
