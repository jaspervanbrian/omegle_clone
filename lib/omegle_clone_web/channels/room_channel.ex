defmodule OmegleCloneWeb.RoomChannel do
  use OmegleCloneWeb, :channel

  @impl true
  def join("room:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def join("room:" <> room_id, payload, socket) do
    if authorized?(payload) do
      # :ok = Room.connect(room_id, self())
      {:ok, assign(socket, :room_id, room_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("signaling", msg, socket) do
    :ok = Room.receive_signaling_msg(socket.assigns.room_id, msg)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_time, session_time}, socket) do
    push(socket, "sessionTime", %{time: session_time})
    {:noreply, socket}
  end

  @impl true
  def handle_info(:session_expired, socket) do
    {:stop, {:shutdown, :session_expired}, socket}
  end

  @impl true
  def terminate(reason, _socket) do
    Logger.info("Stopping Phoenix chnannel, reason: #{inspect(reason)}.")
  end

  # Add authorization logic here as required.
  defp authorized?(_socket) do
    true
  end
end
