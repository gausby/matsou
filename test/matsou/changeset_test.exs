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
end
