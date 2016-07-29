defmodule Matsou.Changeset do
  alias __MODULE__

  @type error :: {String.t, Keyword.t}

  @type action :: :insert | nil
  @type t :: %Changeset{action: action,
                        bucket: binary | nil,
                        type: binary | nil,
                        params: %{String.t => term} | nil,
                        required: [atom],
                        valid?: boolean(),
                        data: Matsou.Schema.t | nil,
                        types: nil | %{atom => Matsou.Type.t}, # todo Matsou.Type
                        changes: %{atom => term},
                        errors: [{atom, error}]}

  defstruct(
    action: nil,
    bucket: nil,
    type: nil,
    params: nil,
    required: [],
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
  def put_change(data, changes, errors, valid?, key, value, type) when is_function(value) do
    new_value = apply(value, [Map.get(data, key)])
    unless is_function(new_value) do
      put_change(data, changes, errors, valid?, key, new_value, type)
    else
      raise message: "an update function should not return a function"
    end
  end

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
  @spec validate_required(t, list(atom) | atom, Keyword.t) :: t
  def validate_required(%{required: required, errors: errors} = changeset, fields, opts \\ []) do
    message = message(opts, "cannot be blank")
    fields = List.wrap(fields)

    new_errors =
      for field <- fields, missing?(changeset, field), is_nil(errors[field]) do
        {field, {message, []}}
      end

    case new_errors do
      [] ->
        %{changeset|required: fields ++ required}

      _ ->
        %{changeset|required: fields ++ required, errors: new_errors ++ errors, valid?: false}
    end
  end

  defp missing?(changeset, field) when is_atom(field) do
    case get_field(changeset, field) do
      value when is_binary(value) ->
        String.lstrip(value) == ""
      value ->
        value == nil
    end
  end
  defp missing?(_changeset, field) do
    raise ArgumentError, "validate_required/3 expects field names to be atoms, got: `#{inspect field}`"
  end

  @doc """

  """
  @spec get_field(t, atom, term) :: term
  def get_field(%Changeset{changes: changes, data: data}, key, default \\ nil) do
    case Map.fetch(changes, key) do
      {:ok, value} ->
        value

      :error ->
        case Map.fetch(data, key) do
          {:ok, value} ->
            value

          :error ->
            default
        end
    end
  end

  @doc """
  Get the value of a changed field, if not present it will return the
  value found in data, and alternatively return a provided default
  value.
  """
  @spec get_change(t, atom, term) :: term
  def get_change(%Changeset{changes: changes}, key, default \\ nil) do
    Map.get(changes, key, default)
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

            value when is_map(value) ->
              {:mapset, MapSet.size(value)}
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
  defp wrong_length(:mapset, _length, value, opts) do
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
  defp too_short(:mapset, _length, value, opts) do
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
  defp too_long(:mapset, _length, value, opts) do
    {message(opts, "should have at most %{count} item(s)"), count: value}
  end

  defp message(opts, key \\ :message, default) do
    Keyword.get(opts, key, default)
  end

  def cast(data, params, allowed) do
    do_cast(data, params, allowed)
  end

  # todo do_cast: guard structs, accept only maps

  defp do_cast(_data, %{__struct__: _} = params, _allowed) do
    raise ArgumentError, message: "expected params to be a map, got: #{inspect params}"
  end

  defp do_cast(%{__struct__: module} = data, params, allowed) do
    do_cast(data, module.__changeset__, %{}, params, allowed)
  end

  # todo do_cast: guard structs without type info
  # todo do_cast: allow an already existing changeset with changes to be passed in as data

  defp do_cast(%{} = data, %{} = types, %{} = changes, :invalid, allowed) when is_list(allowed) do
    allowed = Enum.map(allowed, &process_empty_fields(&1, types))

    %Changeset{data: data, params: nil, valid?: false, errors: [],
               required: allowed, changes: changes, types: types}
  end

  defp do_cast(%{} = data, %{} = types, %{} = changes, %{} = params, allowed) when is_list(allowed) do
    params = normalize_params(params)

    {allowed, {changes, errors, valid?}} =
      Enum.map_reduce(allowed, {changes, [], true},
                      &process_param(&1, :required, params, types, data, &2))

    %Changeset{params: params, data: data, valid?: valid?,
               errors: Enum.reverse(errors), changes: changes, required: allowed,
               types: types}
  end

  defp process_empty_fields(key, _types) when is_binary(key), do: String.to_existing_atom(key)
  defp process_empty_fields(key, _types) when is_atom(key), do: key

  defp process_param(key, kind, params, types, data, {changes, errors, valid?}) do
    {key, param_key} = cast_key(key)
    type = type!(types, key)
    current = Map.get(data, key)

    {key,
     case cast_field(param_key, type, params, current, data, valid?) do
       {:ok, nil, valid?} when kind == :allowed ->
         {errors, valid?} = error_on_nil(kind, key, Map.get(changes, key), errors, valid?)
         {changes, errors, valid?}
       {:ok, value, valid?} ->
         {Map.put(changes, key, value), errors, valid?}
       {:missing, current} ->
         {errors, valid?} = error_on_nil(kind, key, Map.get(changes, key, current), errors, valid?)
         {changes, errors, valid?}
       :invalid ->
         {changes, [{key, {"is invalid", [type: type]}} | errors], false}
     end}
  end

  defp type!(types, key) do
    case Map.fetch(types, key) do
      {:ok, type} ->
        type
      :error ->
        raise ArgumentError, "unknown field `#{key}` (note only fields, " <>
          "embeds, belongs_to, has_one and has_many associations are supported in changesets)"
    end
  end

  defp cast_key(key) when is_binary(key),
    do: {String.to_existing_atom(key), key}
  defp cast_key(key) when is_atom(key),
    do: {key, Atom.to_string(key)}

  defp cast_field(param_key, type, params, current, _data, valid?) do
    case Map.fetch(params, param_key) do
      {:ok, value} ->
        case Matsou.Type.cast(type, value) do
          {:ok, ^current} ->
            {:missing, current}

          {:ok, value} ->
            {:ok, value, valid?}

          :error ->
            :invalid
        end

      :error ->
        {:missing, current}
    end
  end

  # normalize keyword-lists to string key-value maps:
  # [{:key, "value"}] -> [{"key" => "value"}]
  defp normalize_params(params) do
    Enum.reduce(params, nil, fn
      {key, _value}, nil when is_binary(key) ->
        nil

      {key, _value}, _ when is_binary(key) ->
        raise ArgumentError, "expected params to be a map with atoms or string keys, " <>
                             "got a map with mixed keys: #{inspect params}"

      {key, value}, acc when is_atom(key) ->
        Map.put(acc || %{}, Atom.to_string(key), value)

    end) || params
  end

  defp error_on_nil(:allowed, key, nil, errors, _valid?),
    do: {[{key, {"can't be blank", []}} | errors], false}
  defp error_on_nil(_kind, _key, _value, errors, valid?),
    do: {errors, valid?}
end
