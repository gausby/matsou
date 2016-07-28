defmodule Matsou.Type do
  @moduledoc false

  def cast(_type, nil) do
    {:ok, nil}
  end

  def cast(:register, value) when is_binary(value) do
    {:ok, value}
  end

  def cast(:counter, value) when is_binary(value) do
    {:ok, String.to_integer(value)}
  end

  def cast(:set, value) do
    # todo, reconsider how to cast a set
    {:ok, MapSet.new([value])}
  end
end
