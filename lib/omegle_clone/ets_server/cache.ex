defmodule OmegleClone.EtsServer.Cache do
  use GenServer

  @tables ~w(
    rooms room:members room:messages
  )a

  def init(arg) do
    Enum.each(@tables, &:ets.new(&1, [:set, :public, :named_table]))
    {:ok, arg}
  end

  @doc """
  Returns the value for the given ETS table and key. Creates the table if it does
  not exist.

  If a default is provided, this value will be stored in the ETS table and returned.

  ## Examples

      lookup(:"room:messages", "a8ec8230-d865-4eb1-89f5-c259e839a0de")
      #=> nil

      lookup(:"room:messages", "a8ec8230-d865-4eb1-89f5-c259e839a0de", "hello world")
      #=> "hello world"
  """
  def lookup(table_name, key) when table_name in @tables do
    case :ets.lookup(table_name, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def lookup(table_name, key, default) when table_name in @tables do
    case :ets.lookup(table_name, key) do
      [{^key, value}] ->
        value

      [] ->
        insert(table_name, key, default)
        default
    end
  end

  @doc """
  Inserts the value into the ETS tables under the given key.

  ## Examples

      insert(:"room:messages", "a8ec8230-d865-4eb1-89f5-c259e839a0de", "hello world")
      #=> true
  """
  def insert(table_name, key, value) when table_name in @tables do
    :ets.insert(table_name, {key, value})
  end

  @doc """
  Deletes the value from the ETS tables under the given key.

  ## Examples

      delete(:"room:messages", "a8ec8230-d865-4eb1-89f5-c259e839a0de")
      #=> true
  """
  def delete(table_name, key) when table_name in @tables do
    :ets.delete(table_name, key)
  end

  def delete(table_name, key) when is_binary(table_name) do
    String.to_existing_atom(table_name) |> :ets.delete(key)
  end

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end
end
