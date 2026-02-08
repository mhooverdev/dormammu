defmodule DormammuWeb.SessionControllerTest do
  use DormammuWeb.ConnCase

  alias Dormammu.Accounts

  setup do
    {:ok, admin} =
      Accounts.create_admin(%{
        os_username: "admin",
        email: "admin@example.com",
        password: "password123",
        display_name: "Admin User"
      })

    {:ok, user} =
      Accounts.create_user(%{
        os_username: "user",
        email: "user@example.com",
        password: "password123",
        display_name: "Regular User"
      })

    %{admin: admin, user: user}
  end

  test "GET /login", %{conn: conn} do
    conn = get(conn, ~p"/login")
    assert html_response(conn, 200) =~ "Sign In"
  end

  test "GET /login redirects when already logged in as admin", %{conn: conn, admin: admin} do
    conn =
      conn
      |> put_session(:session_user_id, admin.id)
      |> get(~p"/login")

    assert redirected_to(conn) == ~p"/admin"
  end

  test "GET /login redirects when already logged in as user", %{conn: conn, user: user} do
    conn =
      conn
      |> put_session(:session_user_id, user.id)
      |> get(~p"/login")

    assert redirected_to(conn) == ~p"/me/dashboard"
  end

  test "POST /login with valid admin credentials", %{conn: conn, admin: admin} do
    conn =
      post(conn, ~p"/login", %{
        "email" => "admin@example.com",
        "password" => "password123"
      })

    assert redirected_to(conn) == ~p"/admin"
    assert get_session(conn, :session_user_id) == admin.id
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back"
  end

  test "POST /login with valid user credentials", %{conn: conn, user: user} do
    conn =
      post(conn, ~p"/login", %{
        "email" => "user@example.com",
        "password" => "password123"
      })

    assert redirected_to(conn) == ~p"/me/dashboard"
    assert get_session(conn, :session_user_id) == user.id
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back"
  end

  test "POST /login with invalid password", %{conn: conn} do
    conn =
      post(conn, ~p"/login", %{
        "email" => "admin@example.com",
        "password" => "wrongpassword"
      })

    assert html_response(conn, 200) =~ "Invalid email or password"
    assert get_session(conn, :session_user_id) == nil
  end

  test "POST /login with non-existent email", %{conn: conn} do
    conn =
      post(conn, ~p"/login", %{
        "email" => "nonexistent@example.com",
        "password" => "password123"
      })

    assert html_response(conn, 200) =~ "Invalid email or password"
    assert get_session(conn, :session_user_id) == nil
  end

  test "DELETE /logout", %{conn: conn, admin: admin} do
    conn =
      conn
      |> put_session(:session_user_id, admin.id)
      |> delete(~p"/logout")

    assert redirected_to(conn) == ~p"/login"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Signed out"
    assert redirected_to(conn) == ~p"/login"
  end
end
