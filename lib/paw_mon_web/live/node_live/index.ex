defmodule PawMonWeb.NodeLive.Index do
  use PawMonWeb, :live_view

  alias PawMon.PawNode.RPC

  @impl true
  def mount(_params, _session, socket) do
    with(
      {:ok, ip_info} <- ip_info(),
      {:ok, config} <- load_pawmon_config()
    ) do
      description = load_node_description(Map.get(config, "node", %{}))
      socket = socket
      |> assign(:setup_unfinished, :false)
      |> assign(:node_location, node_location(ip_info))
      |> assign(:description, description)
      |> assign(:config, config)
      |> load_full_node_status()

      if connected?(socket) do
        :timer.send_interval(5000, :update)
      end

      {:ok, socket}
    else
      {:error, error} ->
        IO.inspect(error, label: "error")

        socket = socket
        |> assign(:setup_unfinished, :true)

        {:ok, socket}
      error ->
        IO.inspect(error, label: "other error")

        socket = socket
        |> assign(:setup_unfinished, :true)
        {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update, socket) do
    {:noreply, socket
     |> load_full_node_status()}
  end

  def load_full_node_status(socket) do
    node = get_node(socket.assigns.config)
    client = RPC.rpc_client(socket.assigns.config)
    os_data = get_os_data()

    socket = socket
    |> assign(:node, node)
    |> assign(:os_data, os_data)
    |> assign(:page_title, node["name"])
    |> assign(:live_action, :index)

    with(
      {:ok, telemetry} <- RPC.telemetry(client),
      {:ok, block_count} <- RPC.block_count(client),
      {:ok, uptime} <- RPC.uptime(client),
      {:ok, peers} <- RPC.peers(client),
      {:ok, account_balance} <- RPC.account_balance(client, node["account"]),
      {:ok, account_weight} <- RPC.account_weight(client, node["account"]),
      {:ok, delegators_count} <- RPC.delegators_count(client, node["account"]),
      {:ok, reps} <- RPC.reps_online(client),
      {:ok, quorum} <- RPC.confirmation_quorum(client)
    ) do
      socket
      |> assign(:telemetry, telemetry)
      |> assign(:block_count, block_count)
      |> assign(:peer_count, length(Map.keys(peers)))
      |> assign(:rep_count, length(reps))
      |> assign(:account_balance, account_balance)
      |> assign(:account_weight, account_weight)
      |> assign(:delegators_count, delegators_count)
      |> assign(:quorum, quorum)
      |> assign(:uptime, uptime)
      |> assign(:sync_status, sync_status(block_count, telemetry))
      |> assign(:node_quorum, node_quorum(account_weight, quorum))
    else
      error ->
        socket
    end
  end

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
      {:error, error} ->

        IO.inspect(error, label: error)
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

  # build dynamic client based on runtime arguments
  def rpc_client(%{"node" => node}) do
    host = Map.get(node, "host", "localhost")
    rpc_port = Map.get(node, "rpc_port", "7045")

    middleware = [
      {Tesla.Middleware.BaseUrl, "http://#{host}:#{rpc_port}"},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  def format_version(stats) do
    "Paw V#{stats["major_version"]}.#{stats["minor_version"]}.#{stats["patch_version"]}"
  end

  def format_uptime(uptime) do
    uptime
    |> String.to_integer()
    |> Timex.Duration.from_seconds()
    |> PawMon.UptimeFormatter.format()
  end

  def sync_status(%{"count" => local_count}, %{"block_count" => network_count}) do
    min(100, String.to_integer(local_count) / String.to_integer(network_count) * 100)
  end

  def node_quorum(%{"weight" => node_stake}, %{"online_stake_total" => online_stake}) do
    Decimal.new(node_stake)
    |> Decimal.div(Decimal.new(online_stake))
    |> Decimal.mult(100)
  end

  def format_integer(number), do: Number.Delimit.number_to_delimited(number, precision: 0)

  def format_number(number, precision \\ 2), do: Number.Delimit.number_to_delimited(number, precision: precision)

  def format_balance(nil), do: 0
  def format_balance("0"), do: 0
  def format_balance(balance), do: format_number(from_raw(Decimal.new(balance)), 3)

  def from_raw(balance) do
    Decimal.div(balance, Decimal.new("1e27"))
  end

  def qr_url(account) do
    "https://chart.googleapis.com/chart?chs=320x320&cht=qr&chl=paw:#{account}&choe=UTF-8"
  end

  def tracker_url(account) do
    "https://tracker.paw.digital/account/#{account}"
  end

  def paw_account(%{account: "paw_" <> _account} = assigns) do
    ~H"""
    <a
      href={tracker_url(@account)}
      target="_blank"
      title="Show on tracker.paw.digital"
      class="flex group font-mono"
    >
      <span class="text-sky-600 group-hover:text-teal-500 transition-colors duration-100"><span>paw_</span><%= account_prefix(@account) %></span>
      <span class="truncate text-gray-800 group-hover:text-teal-500 transition-colors duration-100"><%= account_middle(@account) %></span>
      <span class="text-amber-600 group-hover:text-teal-500 transition-colors duration-100"><%= account_suffix(@account) %></span>
    </a>
    """
  end
  def paw_account(%{account: nil} = assigns) do
    ~H"""
    <span class="font-mono">not set</span>
    """
  end
  def paw_account(%{account: _account} = assigns) do
    ~H"""
    <span class="font-mono"><%= @account %></span>
    """
  end

  def account_prefix(account), do: String.slice(account, 4, 6)
  def account_middle(account), do: String.slice(account, 10, 48)
  def account_suffix(account), do: String.slice(account, 58, 6)
end
