defmodule OmegleClone.PeerSupervisor do
  @moduledoc false

  use DynamicSupervisor

  require Logger

  alias OmegleClone.Peer

  @type opts :: %{
    username: String.t(),
    channel: pid(),
    lv_id: String.t()
  }

  @spec start_link(any()) :: DynamicSupervisor.on_start_child()
  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @spec add_peer(Peer.id(), String.t(), [String.t()], opts) :: {:ok, pid()}
  def add_peer(id, room_id, peer_ids, opts) do
    peer_opts = [id, room_id, peer_ids, opts]
    gen_server_opts = [name: Peer.registry_id(id)]

    child_spec = %{
      id: Peer,
      start: {Peer, :start_link, [peer_opts, gen_server_opts]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @spec terminate_peer(Peer.id()) :: :ok
  def terminate_peer(peer) do
    try do
      peer |> Peer.registry_id() |> GenServer.stop(:shutdown)
    catch
      _exit_or_error, _e -> :ok
    end

    :ok
  end

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
