defmodule DormammuWeb.Plugs.AssignCurrentUser do
  @moduledoc """
  Assigns `:current_user` from the session. All users log in via the single login page.
  """
  import Plug.Conn
  alias Dormammu.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :session_user_id)
    current_user = if user_id, do: Accounts.get_user(user_id), else: nil

    conn
    |> assign(:current_user, current_user)
    |> assign(:request_path, conn.request_path)
  end
end
