defmodule OmegleClone.Room do
  @moduledoc false

  use GenServer

  require Logger

  alias OmegleClone.{Peer, PeerSupervisor, LiveUpdates}
  alias OmegleClone.EtsServer.Cache

  @peer_ready_timeout_s 10
  @peer_limit 5

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

  @spec add_peer(id(), pid(), String.t()) :: {:ok, Peer.id()} | {:error, :peer_limit_reached}
  def add_peer(room_id, channel_pid, lv_id) do
    GenServer.call(registry_id(room_id), {:add_peer, room_id, channel_pid, lv_id})
  end

  @spec new_message(id(), message()) :: {:noreply, term()}
  def new_message(room_id, message) do
    GenServer.cast(registry_id(room_id), {:new_message, message})
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
  def init([room_id]) do
    state = init_state(room_id)

    {:ok, state}
  end

  @impl true
  def handle_call({:add_peer, _room_id, _channel_pid, _lv_id}, _from, state)
      when map_size(state.pending_peers) + map_size(state.peers) == @peer_limit do
    Logger.warning("Unable to add new peer: reached peer limit (#{@peer_limit})")
    refresh_room_ets_status(state)

    {:reply, {:error, :peer_limit_reached}, state}
  end

  @impl true
  def handle_call({:add_peer, room_id, channel_pid, lv_id}, _from, state) do
    refresh_room_ets_status(state)

    %{id: id, username: username} = generate_peer_info()
    Logger.info("New peer #{id} added")
    peer_ids = Map.keys(state.peers)

    opts = %{
      username: username,
      channel: channel_pid,
      lv_id: lv_id,
    }

    {:ok, pid} = PeerSupervisor.add_peer(id, room_id, peer_ids, opts)
    Process.monitor(pid)

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

    {:reply, {:ok, id}, state}
  end

  @impl true
  def handle_call({:mark_ready, id}, _from, state)
      when is_map_key(state.pending_peers, id) do
    Logger.info("Peer #{id} ready")
    broadcast({:peer_added, id}, state)

    {peer_data, state} = pop_in(state, [:pending_peers, id])
    state = put_in(state, [:peers, id], peer_data)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:mark_ready, id, _peer_ids}, _from, state) do
    Logger.debug("Peer #{id} was already marked as ready, ignoring")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:close_peers, room_id}, _from, %{room_id: room_id} = state) do
    cleanup_all_peers(state)

    state = init_state(room_id)

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:new_message, message} = event, %{room_id: room_id} = state) do
    LiveUpdates.notify("messages:#{room_id}", event)

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
        is_map_key(state.pending_peers, id) ->
          {_peer_data, state} = pop_in(state, [:pending_peers, id])
          :ok = PeerSupervisor.terminate_peer(id)

          state

        is_map_key(state.peers, id) ->
          {_peer_data, state} = pop_in(state, [:peers, id])
          :ok = PeerSupervisor.terminate_peer(id) 
          broadcast({:peer_removed, id}, state)

          state

        true -> state
      end

    refresh_room_ets_status(state)

    {:noreply, state}
  end

  defp init_state(room_id) do
    %{
      room_id: room_id,
      peers: %{},
      pending_peers: %{},
      peer_pid_to_id: %{},
      messages: []
    }
  end

  defp generate_peer_info do
    %{
      id: generate_id(),
      username: UniqueNamesGenerator.generate([:adjectives, :colors, :animals])
    }
  end

  defp generate_id, do: 5 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

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
        status = if peer_count >= @peer_limit do
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
end
