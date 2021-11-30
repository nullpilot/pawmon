defmodule PawMonWeb.PageController do
  use PawMonWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
