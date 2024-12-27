defmodule OmegleClone.Room do
  @moduledoc false

  use GenServer

  require Logger

  alias OmegleClone.{Peer, PeerSupervisor}
  alias OmegleClone.EtsServer.Cache

  @peer_ready_timeout_s 10
  @peer_limit 5

  @type id :: String.t()

  @spec start_link(term(), term()) :: GenServer.on_start()
  def start_link(args, opts) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @spec add_peer(id(), pid()) :: {:ok, Peer.id()} | {:error, :peer_limit_reached}
  def add_peer(room_id, channel_pid) do
    GenServer.call(registry_id(room_id), {:add_peer, room_id, channel_pid})
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
    state = %{
      room_id: room_id,
      peers: %{},
      pending_peers: %{},
      peer_pid_to_id: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:add_peer, _room_id, _channel_pid}, _from, state)
      when map_size(state.pending_peers) + map_size(state.peers) == @peer_limit do
    Logger.warning("Unable to add new peer: reached peer limit (#{@peer_limit})")
    refresh_room_ets_status(state)

    {:reply, {:error, :peer_limit_reached}, state}
  end

  @impl true
  def handle_call({:add_peer, room_id, channel_pid}, _from, state) do
    refresh_room_ets_status(state)

    id = generate_id()
    Logger.info("New peer #{id} added")
    peer_ids = Map.keys(state.peers)

    {:ok, pid} = PeerSupervisor.add_peer(id, room_id, channel_pid, peer_ids)
    Process.monitor(pid)

    peer_data = %{pid: pid, channel: channel_pid}

    state =
      state
      |> put_in([:pending_peers, id], peer_data)
      |> put_in([:peer_pid_to_id, pid], id)

    Process.send_after(self(), {:peer_ready_timeout, id}, @peer_ready_timeout_s * 1000)

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
  def handle_call({:close_peers, _room_id}, _from, state) do
    cleanup_all_peers(state)

    state = %{
      room_id: state.room_id,
      peers: %{},
      pending_peers: %{},
      peer_pid_to_id: %{}
    }

    {:reply, :ok, state}
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

    if peer_count === 0 do
      Cache.delete(:active_rooms, state.room_id)
    else
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
