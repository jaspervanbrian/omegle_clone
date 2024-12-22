defmodule OmegleClone.RoomLive.Auth do
  import Phoenix.LiveView

  def on_mount(:default, %{"id" => id}, _session, socket) do
    if false do
      {:cont, socket}
    else
      {:halt,
        socket
        |> put_flash(:error, "Room not found!")
        |> redirect(to: "/")
      }
    end
  end
end
