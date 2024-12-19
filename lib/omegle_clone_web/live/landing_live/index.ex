defmodule OmegleCloneWeb.LandingLive.Index do
  use OmegleCloneWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Omegle Clone")
  end

  @impl true
  def handle_info({OmegleCloneWeb.MeterReadingLive.FormComponent, {:saved, meter_reading}}, socket) do
    {:noreply, stream_insert(socket, :meter_readings, meter_reading)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    meter_reading = NEM12.get_meter_reading!(id)
    {:ok, _} = NEM12.delete_meter_reading(meter_reading)

    {:noreply, stream_delete(socket, :meter_readings, meter_reading)}
  end
end
