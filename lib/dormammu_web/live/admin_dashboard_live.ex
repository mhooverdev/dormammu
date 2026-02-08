defmodule DormammuWeb.AdminDashboardLive do
  @moduledoc """
  Admin landing page with quick stats.
  """
  use DormammuWeb, :live_view

  alias Dormammu.Accounts
  alias Dormammu.Tracking

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    entries = Tracking.list_entries_all(limit: 10)

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:users, users)
     |> assign(:entries, entries)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-6xl space-y-6 px-4 sm:px-6 lg:px-10">
      <div class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight">Admin Dashboard</h1>
          <p class="text-sm opacity-70">A quick snapshot of what’s happening.</p>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <.link
          navigate={~p"/admin/users"}
          class={[
            "group card bg-gradient-to-br from-base-200 to-base-100 p-5 border border-base-300/60",
            "hover:border-primary/40 hover:shadow-lg hover:shadow-primary/10",
            "transition-all focus:outline-none focus:ring-2 focus:ring-primary/40"
          ]}
          aria-label="Manage users"
        >
          <div class="flex items-start justify-between">
            <div>
              <div class="text-sm opacity-70">Users</div>
              <div class="text-3xl font-bold tracking-tight">{length(@users)}</div>
              <div class="mt-1 text-xs opacity-60">Manage access and status</div>
            </div>
            <div class="mt-1 rounded-full bg-primary/10 px-2 py-1 text-xs font-semibold text-primary group-hover:bg-primary/15">
              Open
            </div>
          </div>
        </.link>

        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Active Entries</div>
          <div class="text-3xl font-bold">
            {Enum.count(@entries, &is_nil(&1.ended_at))}
          </div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Latest Entry</div>
          <div class="text-sm">
            <%= if entry = List.first(@entries) do %>
              {(entry.user && entry.user.display_name) || (entry.user && entry.user.os_username)} · {entry.task_type &&
                entry.task_type.name}
            <% else %>
              None yet
            <% end %>
          </div>
        </div>
      </div>

      <div>
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold">Recent Activity</h2>
          <.link navigate={~p"/admin/reports"} class="btn btn-ghost btn-sm">View all</.link>
        </div>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>User</th>
                <th>Task</th>
                <th>Start</th>
                <th>End</th>
              </tr>
            </thead>
            <tbody>
              <%= for e <- @entries do %>
                <tr>
                  <td>{user_name(e.user)}</td>
                  <td>{e.task_type && e.task_type.name}</td>
                  <td>{fmt(e.started_at)}</td>
                  <td>{fmt(e.ended_at)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
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

  defp user_name(nil), do: "Unknown"
  defp user_name(u), do: u.display_name || u.os_username || u.email || "User"
  defp fmt(nil), do: "—"
  defp fmt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
