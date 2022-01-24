defmodule PawMonWeb.NodeLive.Index do
  use PawMonWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    ip_info = ip_info()
    config = load_pawmon_config()
    description = load_node_description()

    socket = socket
    |> assign(:node_location, node_location(ip_info))
    |> assign(:description, description)
    |> assign(:config, config)
    |> load_full_node_status()

    if connected?(socket) do
      :timer.send_interval(5000, :update)
    end

    {:ok, socket}
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
    client = rpc_client(socket.assigns.config)
    os_data = get_os_data()
    telemetry = telemetry(client)
    block_count = block_count(client)
    uptime = get_uptime(client)
    peers = get_peers(client)
    node = get_node(socket.assigns.config)
    account_balance = account_balance(client, node["account"])
    account_weight = account_weight(client, node["account"])
    delegators_count = get_delegators_count(client, node["account"])
    reps = get_reps_online(client)
    quorum = confirmation_quorum(client)

    socket
    |> assign(:node, node)
    |> assign(:telemetry, telemetry)
    |> assign(:block_count, block_count)
    |> assign(:peer_count, length(Map.keys(peers)))
    |> assign(:rep_count, length(reps))
    |> assign(:os_data, os_data)
    |> assign(:account_balance, account_balance)
    |> assign(:account_weight, account_weight)
    |> assign(:delegators_count, delegators_count)
    |> assign(:quorum, quorum)
    |> assign(:uptime, uptime)
    |> assign(:sync_status, sync_status(block_count, telemetry))
    |> assign(:node_quorum, node_quorum(account_weight, quorum))
    |> assign(:page_title, node["name"])
    |> assign(:live_action, :index)
  end

  def load_pawmon_config() do
    path = Path.expand("./priv/pawmon/config.toml")
    {:ok, config} = :tomerl.read_file(path)

    config
  end

  def load_node_description() do
    path = Path.expand("./priv/pawmon/description.md")
    {:ok, description} = File.read(path)
    {:ok, html, _} = Earmark.as_html(description)

    html
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

  def telemetry(client) do
    case Tesla.post(client, "/", %{action: "telemetry"}) do
      {:ok, %Tesla.Env{status: 200, body: telemetry}} -> telemetry
      {:error, error} -> throw error
    end
  end

  def block_count(client) do
    case Tesla.post(client, "/", %{action: "block_count"}) do
      {:ok, %Tesla.Env{status: 200, body: block_count}} -> block_count
      {:error, error} -> throw error
    end
  end

  def confirmation_quorum(client) do
    case Tesla.post(client, "/", %{action: "confirmation_quorum"}) do
      {:ok, %Tesla.Env{status: 200, body: confirmation_quorum}} -> confirmation_quorum
      {:error, error} -> throw error
    end
  end

  def account_balance(client, account) do
    case Tesla.post(client, "/", %{action: "account_balance", account: account}) do
      {:ok, %Tesla.Env{status: 200, body: account_balance}} -> account_balance
      {:error, error} -> throw error
    end
  end

  def account_weight(client, account) do
    case Tesla.post(client, "/", %{action: "account_weight", account: account}) do
      {:ok, %Tesla.Env{status: 200, body: account_weight}} -> account_weight
      {:error, error} -> throw error
    end
  end

  def get_peers(client) do
    case Tesla.post(client, "/", %{action: "peers"}) do
      {:ok, %Tesla.Env{status: 200, body: %{"peers" => peers}}} -> peers
      {:error, error} -> throw error
    end
  end

  def get_uptime(client) do
    case Tesla.post(client, "/", %{action: "uptime"}) do
      {:ok, %Tesla.Env{status: 200, body: %{"seconds" => uptime}}} -> uptime
      {:error, error} -> throw error
    end
  end

  def get_reps_online(client) do
    case Tesla.post(client, "/", %{action: "representatives_online"}) do
      {:ok, %Tesla.Env{status: 200, body: %{"representatives" => reps}}} -> reps
      {:error, error} -> throw error
    end
  end

  def get_delegators_count(client, account) do
    case Tesla.post(client, "/", %{action: "delegators_count", account: account}) do
      {:ok, %Tesla.Env{status: 200, body: %{"count" => count}}} -> String.to_integer(count)
      {:error, error} -> throw error
    end
  end

  def ip_info() do
    client = Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://ipinfo.io"},
      Tesla.Middleware.JSON
    ])

    case Tesla.get(client, "/5.9.62.111/json") do
      {:ok, %Tesla.Env{status: 200, body: ip_info}} -> ip_info
      {:error, error} -> throw error
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
end
