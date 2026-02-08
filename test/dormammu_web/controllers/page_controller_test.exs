defmodule DormammuWeb.PageControllerTest do
  use DormammuWeb.ConnCase

  alias Dormammu.Accounts

  test "GET / redirects to login when no user", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/login"
  end

  test "GET / redirects to dashboard when user is logged in", %{conn: conn} do
    {:ok, user} =
      Accounts.create_user(%{
        email: "user@test.com",
        password: "password123",
        os_username: "testuser"
      })

    conn =
      conn
      |> put_session(:session_user_id, user.id)
      |> get(~p"/")

    assert redirected_to(conn) == ~p"/me/dashboard"
  end
end
