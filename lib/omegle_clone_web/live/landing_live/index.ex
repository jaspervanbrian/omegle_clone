defmodule OmegleCloneWeb.LandingLive.Index do
  use OmegleCloneWeb, :live_view

  alias OmegleClone.EtsServer.Cache

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("chat_random", _, socket) do
    get_random_available_room()
    |> case do
      {room_id, _} -> {:ok, room_id}
      _ -> create_random_room_and_join()
    end
    |> case do
      {:ok, room_id} ->
        {:noreply,
          socket
          |> push_navigate(to: ~p"/room/#{room_id}", replace: true)
        }

      _ ->
        {:noreply, socket |> put_flash(:error, "Error on joining a chat!")}
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Omegle Clone")
  end

  defp create_random_room_and_join do
    IO.inspect("create")
    room_id = UUID.uuid4()

    case OmegleClone.RoomRegistryServer.create_room(room_id) do
      {:ok, _room_pid} -> {:ok, room_id}

      {:error, reason} ->
        Logger.warning("Error:")
        {:error, %{reason: reason}}
    end
  end

  defp get_random_available_room do
    Cache.match_object(:active_rooms, {:_, %{status: "available"}})
    |> case do
      [] -> nil
      active_rooms -> Enum.random(active_rooms)
    end
  end
end
