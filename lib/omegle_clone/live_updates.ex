defmodule OmegleClone.LiveUpdates do
  def subscribe(room) do
    Phoenix.PubSub.subscribe(OmegleClone.PubSub, room, link: true)
  end

  def notify(room, message) do
    Phoenix.PubSub.broadcast(OmegleClone.PubSub, room, {room, message})
  end
end
