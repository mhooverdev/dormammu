defmodule DormammuWeb.SessionController do
  @moduledoc """
  Single login for all users (admin and regular). Role determines access after login.
  """
  use DormammuWeb, :controller

  alias Dormammu.Accounts

  def new(conn, _params) do
    if conn.assigns[:current_user] do
      redirect_path =
        if conn.assigns.current_user.role == :admin, do: "/admin", else: "/me/dashboard"

      redirect(conn, to: redirect_path)
    else
      render(conn, :new, page_title: "Sign In")
    end
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        redirect_path = if user.role == :admin, do: "/admin", else: "/me/dashboard"

        conn
        |> put_session(:session_user_id, user.id)
        |> put_flash(:info, "Welcome back, #{user.display_name || user.email}")
        |> redirect(to: redirect_path)

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:new, page_title: "Sign In")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Signed out")
    |> redirect(to: "/login")
  end
end
