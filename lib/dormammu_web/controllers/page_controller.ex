defmodule DormammuWeb.PageController do
  use DormammuWeb, :controller

  def home(conn, _params) do
    case get_session(conn, :session_user_id) do
      nil ->
        conn
        |> redirect(to: "/login")

      _user_id ->
        case conn.assigns[:current_user] do
          %{role: :admin} -> redirect(conn, to: "/admin")
          _ -> redirect(conn, to: "/me/dashboard")
        end
    end
  end
end
