defmodule DormammuWeb.Plugs.RequireUser do
  @moduledoc """
  Ensures a current user is present; halts if not.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(%Plug.Conn{assigns: %{current_user: %{} = _user}} = conn, _opts), do: conn

  def call(conn, _opts) do
    conn
    |> put_flash(:error, "Please log in to continue")
    |> redirect(to: "/login")
    |> halt()
  end
end
