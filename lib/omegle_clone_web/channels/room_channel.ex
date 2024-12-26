defmodule OmegleCloneWeb.RoomChannel do
  use OmegleCloneWeb, :channel

  require Logger

  @impl true
  def join("room:" <> room_id, payload, socket) do
    if authorized?(payload) do
      pid = self()
      send(pid, :after_join)

      case OmegleClone.RoomRegistryServer.create_room(room_id) do
        {:ok, _room_pid} ->
          case Room.add_peer(room_id, pid) do
            {:ok, peer_id} ->
              {:ok, assign(socket, %{peer_id: peer_id, room_id: room_id})}

            {:error, _reason} = error -> error
          end

        {:error, reason} ->
          Logger.warning("Error on peer_channel:")
          {:error, %{reason: reason}}
      end

    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("sdp_answer", %{"body" => body}, socket) do
    :ok = Peer.apply_sdp_answer(socket.assigns.peer, body)
    {:noreply, socket}
  end

  @impl true
  def handle_in("sdp_offer", %{"body" => _body}, socket) do
    # TODO: renegotiate
    Logger.warning("Ignoring SDP offer sent by peer #{socket.assigns.peer}")
    {:noreply, socket}
  end

  @impl true
  def handle_in("ice_candidate", %{"body" => body}, socket) do
    Peer.add_ice_candidate(socket.assigns.peer, body)
    {:noreply, socket}
  end

  @impl true
  def handle_cast({:offer, sdp_offer}, socket) do
    push(socket, "sdp_offer", %{"body" => sdp_offer})
    {:noreply, socket}
  end

  @impl true
  def handle_cast({:candidate, candidate}, socket) do
    push(socket, "ice_candidate", %{"body" => candidate})
    {:noreply, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _ref} = Presence.track(socket, socket.assigns.peer, %{})
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    # Optional: Clean up supervisor if this was the last connection
    # You might want to track connection counts per topic first
    if ((socket |> Presence.list |> Enum.count) - 1) <= 0 do
      room_id = socket.assigns.room_id

      OmegleClone.RoomRegistryServer.terminate_room(room_id)
    end

    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_socket) do
    true
  end
end
