defmodule OmegleClone.EtsServer.Cache do
  use GenServer

  @doc """
  Overview of tables:
    - active_rooms: Contains room_ids as keys and information map as value
      > {room_id, info_map}
      > info_map may have %{peer_count: 3, status: "available"} or %{peer_count: 5, status: "full"}
  """

  @tables ~w(
    active_rooms
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
  Matches the args supplied on an ETS table.

  Returns matching results.

  ## Examples

      match(:active_rooms, :"$1")
      #=> nil

      match(:active_rooms, :"$1")
      #=> [[{"a8ec8230-d865-4eb1-89f5-c259e839a0de", 2}]]
  """
  def match(table_name, args) when table_name in @tables do
    :ets.match(table_name, args)
  end

  @doc """
  Matches the args with the objects supplied on an ETS table.

  Returns matching results.

  ## Examples

      match_object(:active_rooms, {:_, %{status: "full"}})
      #=> nil

      match_object(:active_rooms, {:_, %{status: "available"}})
      #=> [[{"a8ec8230-d865-4eb1-89f5-c259e839a0de", %{peer_count: 1, status: "available"}]]
  """
  def match_object(table_name, args) when table_name in @tables do
    :ets.match_object(table_name, args)
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
