defmodule OmegleCloneWeb.RoomLive.Show do
  use OmegleCloneWeb, :live_view

  alias OmegleClone.{
    LiveUpdates,
    Room
  }

  @impl true
  def mount(_params, _session, socket) do
    # Assign some unique client id to communicate with the Room Genserver
    client_id = UUID.uuid4()

    LiveUpdates.subscribe("lv:#{client_id}")

    {:ok, assign(socket, client_id: client_id)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({"lv:" <> client_id, {:init_lv_connection, message}}, %{assigns: %{client_id: client_id, room_id: room_id}} = socket) do
    %{
      peer_id: peer_id,
      username: username,
      messages: messages
    } = message

    LiveUpdates.subscribe("messages:#{room_id}")

    {:ok, timestamp} = DateTime.now("Etc/UTC")

    Room.new_message(room_id, %{
      id: UUID.uuid4(),
      peer_id: peer_id,
      username: username,
      body: "HELLO WORLDO",
      timestamp: timestamp
    })

    socket =
      socket
      |> stream(:messages, messages |> Enum.reverse())
      |> assign(%{
        peer_id: peer_id,
        username: username,
        unread_messages: 0
      })

    {:noreply, socket}
  end

  def handle_info({"messages:" <> room_id, {:new_message, %{peer_id: peer_id}}}, %{assigns: %{peer_id: peer_id, room_id: room_id}} = socket) do
    {:noreply, socket}
  end

  def handle_info({"messages:" <> room_id, {:new_message, message}}, %{assigns: %{room_id: room_id}} = socket) do
    unread_messages = socket.assigns.unread_messages + 1

    {:noreply, assign(socket, unread_messages: unread_messages)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :show, %{"id" => room_id}) do
    socket
    |> assign(page_title: "Omegle Clone", room_id: room_id)
  end

  defp apply_action(socket, _, _params) do
    socket
  end
end
