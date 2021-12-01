defmodule PawMonWeb.NodeLive.Index do
  use PawMonWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    node = get_node()
    stats = node_stats()

    {:ok, socket
     |> assign(:node, node)
     |> assign(:stats, stats)
     |> assign(:page_title, node.name)
     |> assign(:live_action, :index)
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp get_node do
    %{
      name: "Funny Looking Cats 🐼",
      address: "paw_1wcajz9cm5kcgyyg3mhjnhn46kxgggoqt6d8mzpu14um3w14fhknfrpb1dzk"
    }
  end

  defp node_stats do
    %{
      balance: 420,
      pending_balance: 0,
      voting_weight: "32.03M",
      block_count: "25945",
      cemented_count: "16835",
      unchecked_count: "937",
      sync_status: 100,
      major_version: "22",
      minor_version: "1",
      patch_version: "0",
      uptime: "106103",
      cpu_load: 2.462,
      memory_load: 25,
      disk_load: 62,
      vote_weight: 32000000,
      vote_percentage: 0.01
    }
  end

  def format_version(stats) do
    "Paw V#{stats.major_version}.#{stats.minor_version}.#{stats.patch_version}"
  end

  def format_uptime(uptime), do: uptime

  def format_number(number), do: number

  def format_balance(balance), do: "#{balance} PAW"

  def qr_url(address) do
    "https://chart.googleapis.com/chart?chs=320x320&cht=qr&chl=paw:#{address}&choe=UTF-8"
  end

  def tracker_url(address) do
    "https://tracker.paw.digital/account/#{address}"
  end
end
