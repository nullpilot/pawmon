defmodule PawMon.PawNode.RPC do
  # build dynamic client based on runtime arguments
  def rpc_client(%{"node" => node}) do
    host = Map.get(node, "host", "localhost")
    rpc_port = Map.get(node, "rpc_port", "7045")

    middleware = [
      {Tesla.Middleware.BaseUrl, "http://#{host}:#{rpc_port}"},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware, {Tesla.Adapter.Hackney, [recv_timeout: 1_000]})
  end

  def telemetry(client) do
    case Tesla.post(client, "/", %{action: "telemetry"}) do
      {:ok, %Tesla.Env{status: 200, body: telemetry}} -> {:ok, telemetry}
      {:error, error} -> {:error, error}
    end
  end

  def block_count(client) do
    case Tesla.post(client, "/", %{action: "block_count"}) do
      {:ok, %Tesla.Env{status: 200, body: block_count}} -> {:ok, block_count}
      {:error, error} -> {:error, error}
    end
  end

  def confirmation_quorum(client) do
    case Tesla.post(client, "/", %{action: "confirmation_quorum"}) do
      {:ok, %Tesla.Env{status: 200, body: confirmation_quorum}} -> {:ok, confirmation_quorum}
      {:error, error} -> {:error, error}
    end
  end

  def account_balance(client, account) do
    case Tesla.post(client, "/", %{action: "account_balance", account: account}) do
      {:ok, %Tesla.Env{status: 200, body: account_balance}} -> {:ok, account_balance}
      {:error, error} -> {:error, error}
    end
  end

  def account_weight(client, account) do
    case Tesla.post(client, "/", %{action: "account_weight", account: account}) do
      {:ok, %Tesla.Env{status: 200, body: account_weight}} -> {:ok, account_weight}
      {:error, error} -> {:error, error}
    end
  end

  def peers(client) do
    case Tesla.post(client, "/", %{action: "peers"}) do
      {:ok, %Tesla.Env{status: 200, body: %{"peers" => peers}}} -> {:ok, peers}
      {:error, error} -> {:error, error}
    end
  end

  def uptime(client) do
    case Tesla.post(client, "/", %{action: "uptime"}) do
      {:ok, %Tesla.Env{status: 200, body: %{"seconds" => uptime}}} -> {:ok, uptime}
      {:error, error} -> {:error, error}
    end
  end

  def reps_online(client) do
    case Tesla.post(client, "/", %{action: "representatives_online"}) do
      {:ok, %Tesla.Env{status: 200, body: %{"representatives" => reps}}} -> {:ok, reps}
      {:error, error} -> {:error, error}
    end
  end

  def delegators_count(client, account) do
    case Tesla.post(client, "/", %{action: "delegators_count", account: account}) do
      {:ok, %Tesla.Env{status: 200, body: %{"count" => count}}} -> {:ok, String.to_integer(count)}
      {:error, error} -> {:error, error}
    end
  end
end
