defmodule Matsou.ChangesetTest do
  use ExUnit.Case
  doctest Matsou.Schema

  alias Matsou.Changeset

  defmodule MyModule do
    use Matsou.Schema

    schema "user" do
      field :name, :register
      field :age, :counter
    end
  end

  test "changing values" do
    changeset =
      %MyModule{}
      |> Changeset.change(name: "peter")
      |> Changeset.validate_change(:name, fn
           :name, "peter" ->
             []

           :name, _ ->
             [name: "oh, my!"]
         end)

    assert changeset.changes.name == "peter"
    assert changeset.valid? == true
    assert changeset.errors == []
  end

  test "validating exact length of field with a string" do
    topic = "John Doe"
    exact_length =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, is: String.length(topic))
    shorter =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, is: String.length(topic) - 1)
    longer =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, is: String.length(topic) + 1)

    assert exact_length.errors == []
    refute shorter.errors == []
    refute longer.errors == []
  end

  test "validating minimum length of field with a string" do
    topic = "John Doe"
    exact_length =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, min: String.length(topic))
    shorter =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, min: String.length(topic) - 1)
    longer =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, min: String.length(topic) + 1)

    assert exact_length.errors == []
    assert shorter.errors == []
    refute longer.errors == []
  end

  test "validating maximum length of field with a string" do
    topic = "John Doe"
    exact_length =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, max: String.length(topic))
    shorter =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, max: String.length(topic) - 1)
    longer =
      %MyModule{}
      |> Changeset.change(name: topic)
      |> Changeset.validate_length(:name, max: String.length(topic) + 1)

    assert exact_length.errors == []
    refute shorter.errors == []
    assert longer.errors == []
  end
end
