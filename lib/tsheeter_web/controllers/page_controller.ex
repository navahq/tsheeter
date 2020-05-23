defmodule TsheeterWeb.PageController do
  use TsheeterWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
