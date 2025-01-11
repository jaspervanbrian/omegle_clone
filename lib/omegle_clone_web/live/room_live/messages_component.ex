defmodule OmegleCloneWeb.RoomLive.MessagesComponent do
  use OmegleCloneWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
    }
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
