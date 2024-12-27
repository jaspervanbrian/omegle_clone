defmodule OmegleClone.RoomLive.Auth do
  import Phoenix.LiveView

  alias OmegleClone.EtsServer.Cache

  def on_mount(:default, %{"id" => id}, _session, socket) do
    if room_available?(id) do
      {:cont, socket}
    else
      {:halt,
        socket
        |> put_flash(:error, "Room maybe full or not found!")
        |> redirect(to: "/")
      }
    end
  end

  defp room_available?(id) do
    case Cache.match_object(:active_rooms, {id, %{status: "available"}}) do
      [{^id, _}] -> true
      _ -> false
    end
  end
end
