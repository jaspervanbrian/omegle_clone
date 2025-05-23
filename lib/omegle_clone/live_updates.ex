defmodule OmegleClone.LiveUpdates do
  def subscribe(topic) do
    Phoenix.PubSub.subscribe(OmegleClone.PubSub, topic, link: true)
  end

  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(OmegleClone.PubSub, topic)
  end

  def notify(topic, message) do
    Phoenix.PubSub.broadcast(OmegleClone.PubSub, topic, {topic, message})
  end
end
