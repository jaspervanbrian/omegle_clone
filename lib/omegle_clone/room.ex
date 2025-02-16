defmodule OmegleClone.Room do
  @moduledoc false

  use GenServer

  require Logger

  alias OmegleClone.{
    LiveUpdates,
    Peer,
    PeerSupervisor,
    RoomRegistryServer
  }
  alias OmegleClone.EtsServer.Cache

  @peer_ready_timeout_s 10

  @type id :: String.t()
  @type message :: %{
    id: String.t(),
    peer_id: Peer.id(),
    username: String.t(),
    body: String.t(),
    timestamp: DateTime.t()
  }

  @spec start_link(term(), term()) :: GenServer.on_start()
  def start_link(args, opts) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @spec add_peer(id(), pid(), String.t()) :: {:ok, Peer.id()} | {:error, :room_max_count_reached}
  def add_peer(room_id, channel_pid, lv_id) do
    GenServer.call(registry_id(room_id), {:add_peer, room_id, channel_pid, lv_id})
  end

  @spec new_text_message(id(), message()) :: {:noreply, term()}
  def new_text_message(room_id, message) do
    GenServer.cast(registry_id(room_id), {:new_text_message, message})
  end

  @spec mark_ready(id(), Peer.id()) :: :ok
  def mark_ready(room_id, peer) do
    GenServer.call(registry_id(room_id), {:mark_ready, peer})
  end

  @spec close_peers(id()) :: :ok | :error
  def close_peers(room_id) do
    GenServer.call(registry_id(room_id), {:close_peers, room_id})
  end

  @spec registry_id(id()) :: term()
  def registry_id(room_id), do: {:via, Registry, {OmegleClone.RoomRegistry, "room:#{room_id}"}}

  @impl true
  def init([room_id, room_max_count]) do
    state = init_state(room_id, room_max_count)

    {:ok, state}
  end

  @impl true
  def handle_call({:add_peer, _room_id, _channel_pid, _lv_id}, _from, state)
      when map_size(state.pending_peers) + map_size(state.peers) == state.room_max_count do
    Logger.warning("Unable to add new peer: reached max room capacity limit (#{state.room_max_count})")
    refresh_room_ets_status(state)

    {:reply, {:error, :room_max_count_reached}, state}
  end

  @impl true
  def handle_call({:add_peer, room_id, channel_pid, lv_id}, _from, state) do
    peer_info = %{id: id, username: username} = generate_peer_info()
    peer_ids = Map.keys(state.peers)
    opts = %{
      username: username,
      channel: channel_pid,
      lv_id: lv_id,
    }

    {:ok, pid} = PeerSupervisor.add_peer(id, room_id, peer_ids, opts)
    Process.monitor(pid)

    Logger.info("New peer #{id} added")

    peer_data = opts |> Map.put(:pid, pid)

    state =
      state
      |> put_in([:pending_peers, id], peer_data)
      |> put_in([:peer_pid_to_id, pid], id)

    Process.send_after(self(), {:peer_ready_timeout, id}, @peer_ready_timeout_s * 1000)

    LiveUpdates.notify("lv:#{lv_id}", {:init_lv_connection, %{
      peer_id: id,
      username: username,
      messages: state.messages,
      peer_ids: peer_ids
    }})

    refresh_room_ets_status(state)

    {:reply, {:ok, peer_info}, state}
  end

  @impl true
  def handle_call({:mark_ready, id}, _from, state)
      when is_map_key(state.pending_peers, id) do
    Logger.info("Peer #{id} ready")

    broadcast({:peer_added, id}, state)

    {peer_data, state} = pop_in(state, [:pending_peers, id])

    message = %{
      peer_id: id,
      username: peer_data.username,
      body: "#{peer_data.username} has joined the chat.",
      should_render_username: false
    }
    |> create_and_broadcast_message(state.room_id, :peer_info_message)

    state =
      state
      |> Map.put(:messages, [message | state.messages])
      |> put_in([:peers, id], peer_data)

    refresh_room_ets_status(state)

    LiveUpdates.notify("peers:#{state.room_id}", {:peer_added, Map.keys(state.peers)})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:mark_ready, id, _peer_ids}, _from, state) do
    Logger.debug("Peer #{id} was already marked as ready, ignoring")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:close_peers, room_id}, _from, %{room_id: room_id, room_max_count: room_max_count} = state) do
    cleanup_all_peers(state)

    state = init_state(room_id, room_max_count)

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:new_text_message, %{peer_id: peer_id, username: username, body: body}}, %{room_id: room_id} = state) do
    last_message =
      case state.messages do
        [] -> nil
        [recent_message | _] -> recent_message
      end

    should_render_username =
      last_message && (last_message.peer_id !== peer_id || last_message.type !== :text_message)

    message = %{
      peer_id: peer_id,
      username: username,
      body: body,
      should_render_username: should_render_username
    }
    |> create_and_broadcast_message(room_id, :text_message)


    {:noreply, %{state | messages: [message | state.messages]}}
  end

  @impl true
  def handle_info({:peer_ready_timeout, peer}, state) do
    if is_map_key(state.pending_peers, peer) do
      Logger.warning(
        "Removing peer #{peer} which failed to mark itself as ready for #{@peer_ready_timeout_s} s"
      )

      :ok = PeerSupervisor.terminate_peer(peer)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    {id, state} = pop_in(state, [:peer_pid_to_id, pid])
    Logger.info("Peer #{id} down with reason #{inspect(reason)}")

    state =
      cond do
        is_map_key(state.pending_peers, id) -> remove_peer(:pending_peers, id, state)

        is_map_key(state.peers, id) -> remove_peer(:peers, id, state)

        true -> state
      end

    refresh_room_ets_status(state)
    close_room_if_empty(state)

    {:noreply, state}
  end

  defp init_state(room_id, room_max_count) do
    %{
      room_id: room_id,
      peers: %{},
      pending_peers: %{},
      peer_pid_to_id: %{},
      messages: [],
      room_max_count: room_max_count
    }
  end

  defp generate_peer_info do
    %{
      id: generate_id(),
      username: UniqueNamesGenerator.generate([:adjectives, :colors, :animals])
    }
  end

  defp generate_id, do: 5 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

  defp close_room_if_empty(state) do
    peer_ids(state)
    |> Enum.empty?
    |> if do
      RoomRegistryServer.terminate_room(state.room_id)
    end
  end

  defp peer_ids(state) do
    Map.keys(state.peers)
    |> Stream.concat(Map.keys(state.pending_peers))
  end

  defp broadcast(msg, state) do
    state
    |> peer_ids()
    |> Enum.each(&Peer.notify(&1, msg))
  end

  defp cleanup_all_peers(state) do
    state
    |> peer_ids()
    |> Enum.each(&PeerSupervisor.terminate_peer(&1))
  end

  defp refresh_room_ets_status(state) do
    peer_count = map_size(state.pending_peers) + map_size(state.peers)

    case Cache.lookup(:active_rooms, state.room_id) do
      nil -> nil
      _ ->
        status = if peer_count >= state.room_max_count do
          "full"
        else
          "available"
        end

        Cache.insert(:active_rooms, state.room_id, %{
          peer_count: peer_count,
          status: status
        })
    end
  end

  defp create_and_broadcast_message(%{peer_id: peer_id, username: username, should_render_username: should_render_username, body: body}, room_id, type) do
    %{
      id: UUID.uuid4(),
      type: type,
      peer_id: peer_id,
      username: username,
      body: body,
      timestamp: DateTime.utc_now,
      should_render_username: should_render_username
    }
    |> tap(fn message -> LiveUpdates.notify("messages:#{room_id}", {:new_message, message}) end)
  end

  defp remove_peer(type, id, state) when type in [:pending_peers, :peers] do
    {peer_data, state} = pop_in(state, [type, id])
    :ok = PeerSupervisor.terminate_peer(id)

    if type === :peers do
      broadcast({:peer_removed, id}, state)
      LiveUpdates.notify("peers:#{state.room_id}", {:peer_removed, Map.keys(state.peers)})
    end

    message = %{
      peer_id: id,
      username: peer_data.username,
      body: "#{peer_data.username} has left the chat.",
      should_render_username: false
    }
    |> create_and_broadcast_message(state.room_id, :peer_info_message)

    Map.put(state, :messages, [message | state.messages])
  end
end
