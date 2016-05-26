defmodule Matsou do
  @moduledoc """
  An Elixir wrapper around Riak CRDT types.
  """

  def put_meta(struct, opts) do
    update_in struct.__meta__, &update_meta(opts, &1)
  end

  defp update_meta([], meta) do
    meta
  end

  @valid_state [:built, :loaded, :deleted]
  defp update_meta([{:state, state}|rest], meta) when state in @valid_state do
    update_meta(rest, %{meta|state: state})
  end
  defp update_meta([{:state, state}|_rest], _meta) do
    raise ArgumentError, "invalid state #{inspect state}"
  end

  defp update_meta([{:key, key}|rest], meta) do
    update_meta(rest, %{meta|key: key})
  end

  defp update_meta([{:raw, data}|rest], meta) do
    update_meta(rest, %{meta|raw: data})
  end
end
