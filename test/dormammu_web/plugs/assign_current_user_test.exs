defmodule DormammuWeb.Plugs.AssignCurrentUserTest do
  use DormammuWeb.ConnCase

  alias DormammuWeb.Plugs.AssignCurrentUser
  alias Dormammu.Accounts

  test "assigns user from session", %{conn: conn} do
    {:ok, admin} =
      Accounts.create_admin(%{
        os_username: "admin",
        email: "admin@example.com",
        password: "password123"
      })

    conn =
      conn
      |> put_session(:session_user_id, admin.id)
      |> AssignCurrentUser.call([])

    assert conn.assigns.current_user.id == admin.id
  end

  test "assigns nil when no session", %{conn: conn} do
    conn = AssignCurrentUser.call(conn, [])

    assert conn.assigns.current_user == nil
  end
end
