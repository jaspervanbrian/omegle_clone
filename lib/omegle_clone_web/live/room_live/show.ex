defmodule OmegleCloneWeb.RoomLive.Show do
  use OmegleCloneWeb, :live_view

  import OmegleCloneWeb.RoomManagement

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
      message: "",
      peers: [],
      inactivity_interval: nil
    )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_info(:inactive_room, %{assigns: %{room_id: current_room_id}} = socket) do
    get_random_available_room(current_room_id)
    |> case do
      {room_id, _} -> socket |> join_new_room(room_id)

      _ ->
        {:noreply,
          socket
          |> set_inactive_room_interval(2.5)
        }
    end
  end

  @impl true
  def handle_info({"lv:" <> client_id, {:init_lv_connection, message}}, %{assigns: %{client_id: client_id, room_id: room_id}} = socket) do
    %{
      peer_id: peer_id,
      username: username,
      messages: messages,
      peer_ids: peers
    } = message

    LiveUpdates.subscribe("messages:#{room_id}")
    LiveUpdates.subscribe("peers:#{room_id}")

    socket =
      socket
      |> stream(:messages, messages |> Enum.reverse(), reset: true)
      |> assign(%{
        peer_id: peer_id,
        peers: peers,
        username: username,
        unread_messages: 0,
      })
      |> set_inactive_room_interval()
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

  def handle_info({"peers:" <> room_id, {:peer_added, [peer_id] = peers}}, %{assigns: %{room_id: room_id, peer_id: peer_id}} = socket) do
    socket =
      socket
      |> assign(peers: peers)
      |> set_inactive_room_interval(5)

    {:noreply, socket}
  end

  def handle_info({"peers:" <> room_id, {:peer_added, peers}}, %{assigns: %{room_id: room_id}} = socket) do
    socket =
      socket
      |> assign(peers: peers)
      |> set_inactive_room_interval(2.5)

    {:noreply, socket}
  end

  def handle_info({"peers:" <> room_id, {:peer_removed, peers}}, %{assigns: %{room_id: room_id}} = socket) do
    socket =
      socket
      |> assign(peers: peers)
      |> set_inactive_room_interval(2.5)

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

  @impl true
  def handle_event("find_other_rooms", _, %{assigns: %{room_id: current_room_id}} = socket) do
    get_random_available_room(current_room_id)
    |> case do
      {room_id, _} -> {:ok, room_id}
      _ -> create_random_room_and_join()
    end
    |> case do
      {:ok, room_id} -> socket |> join_new_room(room_id)

      _ ->
        {:noreply, socket |> put_flash(:error, "Error on joining a chat!")}
    end
  end

  @impl true
  def terminate(_reason, %{assigns: %{client_id: client_id, room_id: room_id, inactivity_interval: inactivity_interval}} = socket) do
    LiveUpdates.unsubscribe("lv:#{client_id}")
    LiveUpdates.unsubscribe("messages:#{room_id}")
    LiveUpdates.unsubscribe("peers:#{room_id}")

    {:noreply, assign(socket, inactivity_interval: cancel_inactive_room_interval(inactivity_interval))}
  end

  defp apply_action(socket, :show, %{"id" => room_id}) do
    socket
    |> assign(page_title: "Omegle Clone", room_id: room_id)
  end

  defp apply_action(socket, _, _params) do
    socket
  end

  defp join_new_room(%{assigns: %{room_id: current_room_id, inactivity_interval: inactivity_interval}} = socket, room_id) do
    LiveUpdates.unsubscribe("messages:#{current_room_id}")
    LiveUpdates.unsubscribe("peers:#{current_room_id}")

    {:noreply,
      socket
      |> assign(inactivity_interval: cancel_inactive_room_interval(inactivity_interval))
      |> put_flash(:joined_room, "interacted")
      |> push_patch(to: ~p"/room/#{room_id}", replace: true)
      |> push_event("new_room", %{room_id: room_id})
    }
  end

  defp set_inactive_room_interval(%{assigns: %{peers: peers, inactivity_interval: inactivity_interval}} = socket, seconds \\ 5) do
    if is_reference(inactivity_interval) do
      cancel_inactive_room_interval(inactivity_interval)
    end

    inactivity_interval =
      case peers do
        [_] -> start_inactive_room_interval(seconds)
        _ -> nil
      end

    assign(socket, inactivity_interval: inactivity_interval)
  end

  defp start_inactive_room_interval(seconds) do
    Process.send_after(self(), :inactive_room, trunc(seconds * 1000))
  end

  defp cancel_inactive_room_interval(inactivity_interval) when is_reference(inactivity_interval) do
    Process.cancel_timer(inactivity_interval)

    nil
  end

  defp cancel_inactive_room_interval(_), do: nil
end
