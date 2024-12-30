defmodule OmegleClone.RoomSupervisor do
  @moduledoc false

  use DynamicSupervisor

  require Logger

  alias OmegleClone.Room

  @spec start_link(any()) :: DynamicSupervisor.on_start_child()
  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @spec add_room(Room.id()) :: {:ok, pid()}
  def add_room(room_id) do
    room_opts = [room_id]
    gen_server_opts = [name: Room.registry_id(room_id)]

    child_spec = %{
      id: Room,
      start: {Room, :start_link, [room_opts, gen_server_opts]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @spec terminate_room(Room.id()) :: :ok
  def terminate_room(room_id) do
    try do
      # Make sure to cleanup peers first
      room_id |> Room.close_peers()
      room_id |> Room.registry_id() |> GenServer.stop(:shutdown)
    catch
      _exit_or_error, _e -> :ok
    end

    :ok
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
