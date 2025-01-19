defmodule OmegleCloneWeb.RoomLive.Show do
  use OmegleCloneWeb, :live_view

  alias OmegleCloneWeb.RoomLive.MessagesComponent
  alias OmegleClone.{
    LiveUpdates,
    Room
  }

  @impl true
  def mount(_params, _session, socket) do
    # Assign some unique client id to communicate with the Room Genserver
    client_id = UUID.uuid4()

    LiveUpdates.subscribe("lv:#{client_id}")

    {:ok, assign(socket,
      client_id: client_id,
      messages_modal_opened: false,
      peer_id: nil,
      username: nil,
      unread_messages: 0,
      message: ""
    )}
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

    socket =
      socket
      |> stream(:messages, messages |> Enum.reverse())
      |> assign(%{
        peer_id: peer_id,
        username: username,
        unread_messages: 0
      })
      |> push_event("init-lv-connection", %{
        username: username
      })

    {:noreply, socket}
  end

  def handle_info({"messages:" <> room_id, {:new_message, %{peer_id: peer_id} = message}}, %{assigns: %{peer_id: peer_id, room_id: room_id}} = socket) do
    socket =
      socket
      |> assign(unread_messages: 0)
      |> stream_insert(:messages, message)
      |> push_event("new-message", %{message_id: message.id, scroll: true})

    {:noreply, socket}
  end

  def handle_info({"messages:" <> room_id, {:new_message, message}}, %{assigns: %{room_id: room_id}} = socket) do
    unread_messages = socket.assigns.unread_messages + 1
    socket =
      socket
      |> assign(unread_messages: unread_messages)
      |> stream_insert(:messages, message)
      |> push_event("new-message", %{message_id: message.id})

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_messages_modal", _params, socket) do
    {:noreply, assign(socket,
      unread_messages: 0,
      messages_modal_opened: true
    )}
  end

  @impl true
  def handle_event("hide_messages_modal", _params, socket) do
    {:noreply, assign(socket,
      messages_modal_opened: false
    )}
  end

  @impl true
  def handle_event("message_changed", %{"message" => message}, socket) do
    {:noreply, assign(socket,
      message: message
    )}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, %{assigns: %{peer_id: peer_id, room_id: room_id, username: username}} = socket) do
    :ok = Room.new_text_message(room_id, %{
      peer_id: peer_id,
      username: username,
      body: message
    })

    socket =
      socket
      |> assign(message: "")

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
