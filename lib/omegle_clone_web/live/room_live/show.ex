defmodule OmegleCloneWeb.RoomLive.Show do
  use OmegleCloneWeb, :live_view

  alias OmegleClone.LiveUpdates

  @impl true
  def mount(_params, session, socket) do
    # Assign some unique client id to communicate with the Room Genserver
    client_id = UUID.uuid4()

    LiveUpdates.subscribe("lv:#{client_id}")

    {:ok, assign(socket, client_id: client_id)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_info({client_id, message}, socket) do
    IO.inspect("OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO")
    IO.inspect(client_id)
    IO.inspect(message)
    IO.inspect("OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO")

    {:noreply, socket}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Omegle Clone")
  end
end
