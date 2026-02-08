defmodule DormammuWeb.AdminUsersLive do
  @moduledoc """
  Admin view to list and toggle users.
  """
  use DormammuWeb, :live_view

  alias Dormammu.Accounts
  alias Dormammu.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, users: Accounts.list_users(), page_title: "Users")}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    with %User{} = user <- Accounts.get_user(id),
         {:ok, _} <- Accounts.update_user(user, %{active: !user.active}) do
      {:noreply, assign(socket, :users, Accounts.list_users())}
    else
      _ -> {:noreply, put_flash(socket, :error, "Could not update user")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-6xl space-y-4 px-4 sm:px-6 lg:px-10">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight">Users</h1>
          <p class="text-sm opacity-70">Activate, deactivate, and review roles.</p>
        </div>
        <.link navigate={~p"/admin"} class="btn btn-outline btn-sm">Back</.link>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>Email</th>
              <th>OS Username</th>
              <th>Role</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for u <- @users do %>
              <tr>
                <td>{u.email || "—"}</td>
                <td>{u.os_username}</td>
                <td class="capitalize">{u.role}</td>
                <td>{if u.active, do: "Active", else: "Inactive"}</td>
                <td>
                  <button class="btn btn-xs" phx-click="toggle" phx-value-id={u.id}>
                    {if u.active, do: "Deactivate", else: "Activate"}
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    <div id="widget-overlay" class="hidden fixed inset-0 z-50" phx-window-keydown={JS.add_class("hidden", to: "#widget-overlay")} phx-key="escape">
      <div
        class="absolute inset-0 bg-black/40 transition-opacity cursor-pointer"
        phx-click={JS.add_class("hidden", to: "#widget-overlay")}
        aria-label="Close widget"
      >
      </div>
      <div class="absolute bottom-4 right-4 z-10">
        <%= live_render(@socket, DormammuWeb.WidgetLive, id: "widget") %>
      </div>
    </div>
    """
  end
end
