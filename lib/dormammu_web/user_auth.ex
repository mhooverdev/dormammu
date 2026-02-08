defmodule DormammuWeb.UserAuth do
  @moduledoc """
  LiveView authentication helpers.

  Ensures `:current_user` is assigned for LiveViews (connected + disconnected),
  and provides role-based guards.
  """

  import Phoenix.LiveView
  import Phoenix.Component
  alias Dormammu.Accounts

  @session_key "session_user_id"

  # Mount current user (if any) from the session for all LiveViews.
  def on_mount(:mount_current_user, _params, session, socket) do
    user_id = session[@session_key]

    current_user =
      case user_id do
        nil -> nil
        id -> Accounts.get_user(id)
      end

    {:cont, assign(socket, :current_user, current_user)}
  end

  # Require any logged-in user.
  def on_mount(:ensure_user, _params, _session, %{assigns: %{current_user: %{}}} = socket) do
    {:cont, socket}
  end

  def on_mount(:ensure_user, _params, _session, socket) do
    {:halt, redirect(socket, to: "/login")}
  end

  # Require an admin user.
  def on_mount(
        :ensure_admin,
        _params,
        _session,
        %{assigns: %{current_user: %{role: :admin}}} = socket
      ) do
    {:cont, socket}
  end

  def on_mount(:ensure_admin, _params, _session, socket) do
    {:halt, redirect(socket, to: "/login")}
  end
end
