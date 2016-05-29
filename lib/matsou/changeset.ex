defmodule Matsou.Changeset do
  alias __MODULE__

  @type error :: {String.t, Keyword.t}

  @type action :: :insert | nil
  @type t :: %Changeset{action: action,
                        bucket: binary | nil,
                        type: binary | nil,
                        valid?: boolean(),
                        data: Matsou.Schema.t | nil,
                        types: nil | %{atom => Matsou.Type.t}, # todo Matsou.Type
                        changes: %{atom => term},
                        errors: [{atom, error}]}

  defstruct(
    action: nil,
    bucket: nil,
    type: nil,
    valid?: nil,
    data: nil,
    types: nil,
    changes: %{},
    errors: [],
    validations: []
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

  @spec validate_change(t, atom, term, (atom, term -> [error])) :: t
  def validate_change(%{validations: validations} = changeset, field, metadata, validator) do
    changeset = %{changeset | validations: [{field, metadata}|validations]}
    validate_change(changeset, field, validator)
  end

  @doc """

  """
  def validate_required() do
    # todo
  end

  @doc """

  """
  def validate_length(changeset, field, opts) when is_list(opts) do
    validate_change(changeset, field, {:length, opts}, fn _, value ->
        {type, length} =
          case value do
            value when is_binary(value) ->
              {:string, String.length(value)}

            value when is_list(value) ->
              {:list, length(value)}
          end

          error =
            ((is = opts[:is]) && wrong_length(type, length, is, opts)) ||
            ((min = opts[:min]) && too_short(type, length, min, opts)) ||
            ((max = opts[:max]) && too_long(type, length, max, opts))

          if error, do: [{field, error}], else: []
    end)
  end

  defp wrong_length(_type, value, value, _opts) do
    nil
  end
  defp wrong_length(:string, _length, value, opts) do
    {message(opts, "should be %{count} character(s)"), count: value}
  end
  defp wrong_length(:list, _length, value, opts) do
    {message(opts, "should have %{count} item(s)"), count: value}
  end

  defp too_short(_type, length, value, _opts) when length >= value do
    nil
  end
  defp too_short(:string, _length, value, opts) do
    {message(opts, "should be at least %{count} character(s)"), count: value}
  end
  defp too_short(:list, _length, value, opts) do
    {message(opts, "should have at least %{count} item(s)"), count: value}
  end

  defp too_long(_type, length, value, _opts) when length <= value do
    nil
  end
  defp too_long(:string, _length, value, opts) do
    {message(opts, "should be at most %{count} character(s)"), count: value}
  end
  defp too_long(:list, _length, value, opts) do
    {message(opts, "should have at most %{count} item(s)"), count: value}
  end

  defp message(opts, key \\ :message, default) do
    Keyword.get(opts, key, default)
  end
end
