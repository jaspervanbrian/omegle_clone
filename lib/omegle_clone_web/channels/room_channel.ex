defmodule OmegleCloneWeb.RoomChannel do
  use OmegleCloneWeb, :channel

  require Logger

  alias OmegleClone.{Peer, RoomRegistryServer}
  alias OmegleCloneWeb.Presence

  @spec send_offer(GenServer.server(), String.t()) :: :ok
  def send_offer(channel, offer) do
    GenServer.cast(channel, {:offer, offer})
  end

  @spec send_candidate(GenServer.server(), String.t()) :: :ok
  def send_candidate(channel, candidate) do
    GenServer.cast(channel, {:candidate, candidate})
  end

  @spec add_peer_info(GenServer.server(), map()) :: :ok
  def add_peer_info(channel, peer_info) do
    GenServer.cast(channel, {:add_peer_info, peer_info})
  end

  @spec close(GenServer.server()) :: :ok
  def close(channel) do
    try do
      GenServer.stop(channel, :shutdown)
    catch
      _exit_or_error, _e -> :ok
    end

    :ok
  end

  @impl true
  def join("room:" <> room_id, payload, socket) do
    if authorized?(payload) do
      %{
        "client_id" => client_id,
        "video" => video_active,
        "audio" => audio_active,
      } = payload

      pid = self()
      send(pid, :after_join)

      case RoomRegistryServer.join_room(room_id, pid, client_id) do
        {:ok, peer_info} ->
          %{id: peer_id, username: username} = peer_info

          {:ok,
            assign(socket, %{
              peer_id: peer_id,
              username: username,
              room_id: room_id,
              lv_id: client_id,
              video_active: video_active,
              audio_active: audio_active
            })
          }

        {:error, _reason} = error -> error
      end

    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("sdp_answer", %{"body" => body}, socket) do
    :ok = Peer.apply_sdp_answer(socket.assigns.peer_id, body)
    {:noreply, socket}
  end

  @impl true
  def handle_in("sdp_offer", %{"body" => _body}, socket) do
    # TODO: renegotiate
    Logger.warning("Ignoring SDP offer sent by peer #{socket.assigns.peer_id}")
    {:noreply, socket}
  end

  @impl true
  def handle_in("ice_candidate", %{"body" => body}, socket) do
    Peer.add_ice_candidate(socket.assigns.peer_id, body)
    {:noreply, socket}
  end

  @impl true
  def handle_in("media_update", %{"video" => video_active, "audio" => audio_active}, socket) do
    {:ok, _ref} = Presence.update(socket, socket.assigns.peer_id, %{
      username: socket.assigns.username,
      video_active: video_active,
      audio_active: audio_active
    })
    IO.inspect("==============")
    IO.inspect(Presence.list(socket))
    IO.inspect("==============")

    push(socket, "presence_state", Presence.list(socket))

    {:noreply, assign(socket, video_active: video_active, audio_active: audio_active) }
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
  def handle_cast({:add_peer_info, peer_info}, socket) do
    push(socket, "add_peer_info", peer_info)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _ref} = Presence.track(socket, socket.assigns.peer_id, %{
      username: socket.assigns.username,
      video_active: socket.assigns.video_active,
      audio_active: socket.assigns.audio_active
    })

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
