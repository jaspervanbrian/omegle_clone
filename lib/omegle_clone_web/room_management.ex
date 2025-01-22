defmodule OmegleCloneWeb.RoomManagement do
  @moduledoc false

  import OmegleCloneWeb.RoomManagement

  alias OmegleClone.RoomRegistryServer
  alias OmegleClone.EtsServer.Cache

  def get_random_available_room(current_room_id // nil) do
    Cache.match_object(:active_rooms, {:_, %{status: "available"}})
    |> then(fn available_rooms ->
      if current_room_id do
        Enum.reject(fn {room_id, _} -> room_id === current_room_id end)
      else
        available_rooms
      end
    )
    |> case do
      [] -> nil
      active_rooms -> Enum.random(active_rooms)
    end
  end

  def create_random_room_and_join do
    room_id = UUID.uuid4()

    case RoomRegistryServer.create_room(room_id) do
      {:ok, _room_pid} -> {:ok, room_id}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
end
