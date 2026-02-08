defmodule DormammuWeb.Plugs.RequireAdmin do
  @moduledoc """
  Ensures an admin user is present; otherwise redirects to login.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(%Plug.Conn{assigns: %{current_user: %{role: :admin} = _user}} = conn, _opts), do: conn

  def call(conn, _opts) do
    conn
    |> put_flash(:error, "Admin access required")
    |> redirect(to: "/login")
    |> halt()
  end
end
