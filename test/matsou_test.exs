defmodule MatsouTest do
  use ExUnit.Case
  doctest Matsou

  defmodule MyModule do
    use Matsou.Schema

    schema "user" do
      field :name, :register
      field :age, :counter
    end
  end

  defmodule MyModuleWithBucketType do
    use Matsou.Schema
    @bucket_type "foo"
    schema "user" do
      field :name, :register
      field :age, :counter
    end
  end

  test "should return a struct" do
    assert Map.has_key? %MyModule{}, :name
    assert Map.has_key? %MyModule{}, :age
  end

  test "should set bucket type to default if none is specified" do
    assert MyModule.__schema__(:type) == "default"
  end

  test "a bucket type should be specifiable" do
    assert MyModuleWithBucketType.__schema__(:type) == "foo"
  end
end
