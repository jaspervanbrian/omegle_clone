defmodule OmegleClone.RoomRegistryServer do
  @moduledoc false

  use GenServer

  require Logger

  alias OmegleClone.RoomSupervisor
  alias OmegleClone.EtsServer.Cache

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def create_room(room_id) do
    GenServer.call(__MODULE__, {:create_room, room_id})
  end

  def get_room(room_id) do
    GenServer.call(__MODULE__, {:get_room, room_id})
  end

  def get_rooms do
    GenServer.call(__MODULE__, {:get_rooms})
  end

  def get_room_ids do
    GenServer.call(__MODULE__, {:get_room_ids})
  end

  def terminate_room(room_id) do
    GenServer.call(__MODULE__, {:terminate_room, room_id})
  end

  def handle_call({:create_room, room_id}, _from, state) do
    case Map.get(state, room_id) do
      nil ->
        case RoomSupervisor.add_room(room_id) do
          {:ok, supervisor} ->
            {:reply, {:ok, supervisor}, Map.put(state, room_id, supervisor)}

          {:error, {:already_started, supervisor}} ->
            Logger.info("Supervisor already exists for room_id: #{room_id}")
            {:reply, {:ok, supervisor}, Map.put(state, room_id, supervisor)}

          error ->
            Logger.error("Failed to start supervisor for room_id: #{room_id}, error: #{inspect(error)}")
            error
        end

      supervisor ->
        {:reply, {:ok, supervisor}, state}
    end
  end

  def handle_call({:get_room, room_id}, _from, state) do
    {:reply, Map.get(state, room_id), state}
  end

  def handle_call({:get_rooms}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get_room_ids}, _from, state) do
    {:reply, state |> Map.keys, state}
  end

  def handle_call({:terminate_room, room_id}, _from, state) do
    {room_pid, state} = Map.pop(state, room_id)
    Cache.delete(:active_rooms, room_id)

    {:reply, RoomSupervisor.terminate_room(room_id), state}
  end
end
