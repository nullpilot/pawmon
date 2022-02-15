defmodule PawMonWeb.NodeLive.Index do
  use PawMonWeb, :live_view

  alias Phoenix.PubSub
  alias PawMon.PawNode

  @impl true
  def mount(_params, _session, socket) do
    status = PawNode.full_node_status()

    if connected?(socket) do
      PubSub.subscribe(PawMon.PubSub, "paw_node")
    end

    {:ok, assign(socket, status)}
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
  def handle_info({:status_update, status}, socket) do
    {:noreply, assign(socket, status)}
  end

  def format_version(%{
    "major_version" => major_version,
    "minor_version" => minor_version,
    "patch_version" => patch_version
  }) do
    "Paw V#{major_version}.#{minor_version}.#{patch_version}"
  end
  def format_version(_), do: "???"

  def format_uptime(nil), do: "???"
  def format_uptime(uptime) do
    uptime
    |> String.to_integer()
    |> Timex.Duration.from_seconds()
    |> PawMon.UptimeFormatter.format()
  end

  def format_downtime(downtime) do
    downtime
    |> Timex.Duration.from_seconds()
    |> PawMon.UptimeFormatter.format()
  end

  def format_integer(nil), do: "?"
  def format_integer(number), do: Number.Delimit.number_to_delimited(number, precision: 0)

  def format_number(num, precision \\ 2)
  def format_number(nil, _), do: "?"
  def format_number(number, precision), do: Number.Delimit.number_to_delimited(number, precision: precision)

  def format_balance(nil), do: "?"
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
