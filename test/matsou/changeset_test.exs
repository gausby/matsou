defmodule Matsou.ChangesetTest do
  use ExUnit.Case
  doctest Matsou.Schema

  alias Matsou.Changeset

  defmodule MyModule do
    use Matsou.Schema

    schema "user" do
      field :name, :register
      field :age, :counter
      field :interests, :set
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

  test "getting a field from a changeset" do
    changeset =
      %MyModule{age: 32, name: "not Joe"}
      |> Changeset.change(name: "Joe")

    # get the field from data if not present in changes
    assert 32 = Changeset.get_field(changeset, :age)
    # get field from changes if present in changes
    assert "Joe" = Changeset.get_field(changeset, :name)
  end

  test "getting a changed field from a changeset" do
    changeset =
      %MyModule{age: 32, name: "not Joe"}
      |> Changeset.change(name: "Joe")

    # get field from changes if present in changes
    assert "Joe" = Changeset.get_change(changeset, :name)
    # return nil if not found in changes
    assert nil == Changeset.get_change(changeset, :age)
    # return a default value if provided and the field is not found in
    # changes
    assert 40 = Changeset.get_change(changeset, :age, 40)
  end

  describe "casting value" do
    test "casting strings allowing everything" do
      params = %{"name" => "John Doe", "age" => "58", "interests" => "foo"}
      changeset =
        Changeset.cast(%MyModule{}, params, [:name, :age, :interests])

      expected_interests = MapSet.new(["foo"])
      assert %Matsou.Changeset{changes: %{interests: ^expected_interests,
                                          name: "John Doe",
                                          age: 58}} = changeset
    end

    test "casting strings omitting some" do
      params = %{"name" => "John Doe", "age" => "58", "interests" => "foo"}
      changeset =
        Changeset.cast(%MyModule{}, params, [:name, :age])

      assert %Matsou.Changeset{changes: %{name: "John Doe",
                                          age: 58}} = changeset
    end

    test "casting invalid" do
      changeset =
        Changeset.cast(%MyModule{}, :invalid, [:name, :age, :interests])

      assert %Matsou.Changeset{changes: %{}} = changeset
    end

    test "casting strings and checking for required fields" do
      params = %{"name" => "John Doe", "age" => "52"}

      assert %Matsou.Changeset{valid?: false} =
        %MyModule{}
        |> Changeset.cast(Map.drop(params, ["age"]), [:name, :age])
        |> Changeset.validate_required([:name, :age])

      assert %Matsou.Changeset{valid?: true} =
        %MyModule{}
        |> Changeset.cast(params, [:name, :age])
        |> Changeset.validate_required([:name, :age])

      # already present values should count
      assert %Matsou.Changeset{valid?: true} =
        %MyModule{age: 32}
        |> Changeset.cast(Map.drop(params, ["age"]), [:name, :age])
        |> Changeset.validate_required([:name, :age])
    end
  end

  describe "validating length of registers" do
    test "validating exact length" do
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

    test "validating minimum length" do
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

    test "validating maximum length" do
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

  describe "validating set fields" do
    test "validating exact size" do
      topic = MapSet.new(["foo", "bar", "baz"])
      exact_length =
        %MyModule{}
        |> Changeset.change(interests: topic)
        |> Changeset.validate_length(:interests, is: MapSet.size(topic))
      shorter =
        %MyModule{}
        |> Changeset.change(interests: topic)
        |> Changeset.validate_length(:interests, is: MapSet.size(topic) - 1)
      longer =
        %MyModule{}
        |> Changeset.change(interests: topic)
        |> Changeset.validate_length(:interests, is: MapSet.size(topic) + 1)

      assert exact_length.errors == []
      refute shorter.errors == []
      refute longer.errors == []
    end

    test "validating minimum size" do
      topic = MapSet.new(["foo", "bar", "baz"])
      exact_length =
        %MyModule{}
        |> Changeset.change(interests: topic)
        |> Changeset.validate_length(:interests, min: MapSet.size(topic))
      shorter =
        %MyModule{}
        |> Changeset.change(interests: topic)
        |> Changeset.validate_length(:interests, min: MapSet.size(topic) - 1)
      longer =
        %MyModule{}
        |> Changeset.change(interests: topic)
        |> Changeset.validate_length(:interests, min: MapSet.size(topic) + 1)

      assert exact_length.errors == []
      assert shorter.errors == []
      refute longer.errors == []
    end

    test "validating maximum size" do
      topic = MapSet.new(["foo", "bar", "baz"])
      exact_length =
        %MyModule{}
        |> Changeset.change(interests: topic)
        |> Changeset.validate_length(:interests, max: MapSet.size(topic))
      shorter =
        %MyModule{}
        |> Changeset.change(name: topic)
        |> Changeset.validate_length(:name, max: MapSet.size(topic) - 1)
      longer =
        %MyModule{}
        |> Changeset.change(name: topic)
        |> Changeset.validate_length(:name, max: MapSet.size(topic) + 1)

      assert exact_length.errors == []
      refute shorter.errors == []
      assert longer.errors == []
    end
  end
end
