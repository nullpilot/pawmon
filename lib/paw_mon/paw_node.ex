defmodule PawMon.PawNode do
  use GenServer

  alias Phoenix.PubSub
  alias PawMon.PawNode.RPC

  # Callbacks

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def full_node_status() do
    GenServer.call(__MODULE__, :status, 10000)
  end

  # Server (callbacks)

  @impl true
  def init(_) do
    state = with(
      {:ok, ip_info} <- ip_info(),
      {:ok, config} <- load_pawmon_config()
    ) do
      node = get_node(config)
      description = load_node_description(Map.get(config, "node", %{}))
      state = %{}
      |> Map.put(:live_action, :index)
      |> Map.put(:page_title, node["name"])
      |> Map.put(:node, node)
      |> Map.put(:setup_unfinished, :false)
      |> Map.put(:node_location, node_location(ip_info))
      |> Map.put(:description, description)
      |> Map.put(:config, config)
      |> Map.put(:rpc_failed, false)
      |> Map.put(:previously_online, false)
      |> Map.put(:downtime, 0)
      |> Map.put(:initializing, true)
      |> load_os_data()
      |> trigger_status_update()

      :timer.send_interval(5000, :update)

      state
    else
      {:error, error} ->
        IO.inspect(error, label: "error")

        state = %{}
        |> Map.put(:setup_unfinished, :true)

        state
      error ->
        IO.inspect(error, label: "unexpected_error")

        state = %{}
        |> Map.put(:setup_unfinished, :true)

        state
    end

    {:ok, state}
  end

  def trigger_status_update(state) do
    Task.Supervisor.async_nolink(PawMon.TaskSupervisor, fn -> load_full_node_status(state) end)

    state
  end

  @impl true
  def handle_info(:update, state) do
    trigger_status_update(state)

    {:noreply, state}
  end

  # If the task succeeds...
  def handle_info({ref, node_status}, state) do
    # The task succeed so we can cancel the monitoring and discard the DOWN message
    Process.demonitor(ref, [:flush])

    state = Map.merge(state, node_status)
    |> Map.put(:initializing, false)

    PubSub.broadcast(PawMon.PubSub, "paw_node", {:status_update, state})
    {:noreply, state}
  end

  # If the task fails...
  def handle_info({:DOWN, _ref, _, _, reason}, state) do
    IO.puts "Status update failed with reason #{inspect(reason)}"

    state = state
    |> Map.put(:initializing, false)

    {:noreply, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state, state}
  end

  def load_os_data(state) do
    os_data = get_os_data()

    state
    |> Map.put(:os_data, os_data)
  end

  def load_full_node_status(state) do
    client = RPC.rpc_client(state.config)

    node_status = %{}

    with(
      {:ok, telemetry} <- RPC.telemetry(client),
      {:ok, block_count} <- RPC.block_count(client),
      {:ok, uptime} <- RPC.uptime(client),
      {:ok, peers} <- RPC.peers(client),
      {:ok, account_balance} <- RPC.account_balance(client, state.node["account"]),
      {:ok, account_weight} <- RPC.account_weight(client, state.node["account"]),
      {:ok, delegators_count} <- RPC.delegators_count(client, state.node["account"]),
      {:ok, reps} <- RPC.reps_online(client),
      {:ok, quorum} <- RPC.confirmation_quorum(client)
    ) do
      node_status
      |> Map.put(:telemetry, telemetry)
      |> Map.put(:block_count, block_count)
      |> Map.put(:peer_count, length(Map.keys(peers)))
      |> Map.put(:rep_count, length(reps))
      |> Map.put(:account_balance, account_balance)
      |> Map.put(:account_weight, account_weight)
      |> Map.put(:delegators_count, delegators_count)
      |> Map.put(:quorum, quorum)
      |> Map.put(:uptime, uptime)
      |> Map.put(:sync_status, sync_status(block_count, telemetry))
      |> Map.put(:node_quorum, node_quorum(account_weight, quorum))
      |> Map.put(:rpc_failed, false)
      |> Map.put(:previously_online, true)
      |> Map.put(:last_online, System.os_time(:second))
      |> load_os_data()

    else
      _error ->
        node_status
        |> assign_downtime()
        |> Map.put(:rpc_failed, true)
    end
  end

  defp assign_downtime(%{last_online: last_online} = state) do
    now = System.os_time(:second)

    state
    |> Map.put(:downtime, now - last_online)
  end
  defp assign_downtime(state), do: Map.put(state, :downtime, nil)

  def load_pawmon_config() do
    path = Path.join([data_dir(), "/config.toml"])

    IO.inspect(path, label: "config path")
    :tomerl.read_file(path)
  end

  def load_node_description(node_config) do
    path = Path.join([data_dir(), "/description.md"])
    node_name = Map.get(node_config, "name", "PAW node 🐾")

    IO.inspect(path, label: "markdown path")
    raw_description = case File.read(path) do
      {:ok, raw_description} -> raw_description
      {:error, _error} ->
        """
        # #{ node_name }

        Description not set. Configure your data directory and create a `description.md` to change this section.
        """
    end

    {:ok, html, _} = Earmark.as_html(raw_description)

    html
  end

  defp data_dir() do
    opts = Application.get_env(:paw_mon, PawMon.DynamicConfig, [])
    default_path = Path.expand("/priv/pawmon/", Application.app_dir(:paw_mon))

    opts
    |> Keyword.get(:data_dir, default_path)
    |> Path.expand()
  end

  def get_os_data() do
    gb = Integer.pow(1024, 3)
    {mem_total, mem_allocated, _} = :memsup.get_memory_data()

    used_memory_percent = mem_allocated / mem_total * 100

    %{
      cpu_avg1: :cpu_sup.avg1(),
      cpu_avg5: :cpu_sup.avg5(),
      cpu_avg15: :cpu_sup.avg15(),
      cpu_load: :cpu_sup.util(),
      memory_percent: used_memory_percent,
      memory_total: mem_total / gb,
      memory_allocated: mem_allocated / gb
    }
  end

  defp get_node(config) do
    config["node"]
  end

  def ip_info() do
    client = Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://ipinfo.io"},
      Tesla.Middleware.JSON
    ])

    case Tesla.get(client, "/5.9.62.111/json") do
      {:ok, %Tesla.Env{status: 200, body: ip_info}} -> {:ok, ip_info}
      {:error, error} -> {:error, error}
    end
  end

  def node_location(ip_info), do: "#{ip_info["city"]}, #{ip_info["country"]}"

  def sync_status(%{"count" => local_count}, %{"block_count" => network_count}) do
    min(100, String.to_integer(local_count) / String.to_integer(network_count) * 100)
  end

  def node_quorum(%{"weight" => node_stake}, %{"online_stake_total" => online_stake}) do
    Decimal.new(node_stake)
    |> Decimal.div(Decimal.new(online_stake))
    |> Decimal.mult(100)
  end
end
