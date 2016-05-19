defmodule Matsou.Changeset do
  alias __MODULE__

  @type error :: {String.t, Keyword.t}

  @type action :: :insert | nil
  @type t :: %Changeset{action: action,
                        bucket: binary | nil,
                        valid?: boolean(),
                        data: Matsou.Schema.t | nil,
                        types: nil | %{atom => Matsou.Type.t}, # todo Matsou.Type
                        changes: %{atom => term},
                        errors: [{atom, error}]}

  defstruct(
    action: nil,
    bucket: nil,
    valid?: nil,
    data: nil,
    types: nil,
    changes: %{},
    errors: []
  )

  def change(data, changes \\ %{})
  def change(%{__struct__: struct} = data, changes) when is_map(changes) or is_list(changes) do
    types = struct.__changeset__

    {changes, errors, valid?} =
      get_changed(data, types, %{}, changes, [], true)

    %Changeset{valid?: valid?, data: data, types: types, changes: changes, errors: errors}
  end

  defp get_changed(data, types, old_changes, new_changes, errors, valid?) do
    Enum.reduce(new_changes, {old_changes, errors, valid?}, fn
      {key, value}, {changes, errors, valid?} ->
        put_change(data, changes, errors, valid?, key, value, Map.get(types, key))
    end)
  end

  @doc """

  """
  def put_change(data, changes, errors, valid?, key, value, _type) do
    cond do
      Map.get(data, key) != value ->
        {Map.put(changes, key, value), errors, valid?}

      Map.has_key?(changes, key) ->
        {Map.delete(changes, key), errors, valid?}

      true ->
        {changes, errors, valid?}
    end
  end

  @doc """

  """
  @spec validate_change(t, atom, (atom, term -> [error])) :: t
  def validate_change(changeset, field, validator) when is_atom(field) do
    %{changes: changes, errors: errors} = changeset

    value = Map.get(changes, field)
    new = if is_nil(value), do: [], else: validator.(field, value)

    case new do
      [] ->
        changeset

      [_|_] ->
        %{changeset | errors: new ++ errors, valid?: false}
    end
  end
end
