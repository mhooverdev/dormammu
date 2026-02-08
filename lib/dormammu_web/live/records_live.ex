defmodule DormammuWeb.RecordsLive do
  @moduledoc """
  LiveView to display and export the current user's time records.
  """
  use DormammuWeb, :live_view

  alias Dormammu.Tracking
  alias Dormammu.Accounts.User

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: %User{} = user}} = socket) do
    entries = Tracking.list_entries(user)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:entries, entries)
     |> assign(:page_title, "My Time Records")}
  end

  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: "/")}

  @impl true
  def handle_event("refresh", _params, %{assigns: %{user: user}} = socket) do
    {:noreply, assign(socket, :entries, Tracking.list_entries(user))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-semibold">My Time Records</h1>
          <p class="text-sm opacity-70">Only your own entries are visible here.</p>
        </div>
        <div class="flex gap-2">
          <a class="btn btn-outline btn-sm" href={~p"/me/records/export.csv"}>Export CSV</a>
          <button class="btn btn-primary btn-sm" phx-click="refresh">Refresh</button>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>Task</th>
              <th>Start</th>
              <th>End</th>
              <th>Duration</th>
              <th>Notes</th>
            </tr>
          </thead>
          <tbody>
            <%= for entry <- @entries do %>
              <tr>
                <td>{entry.task_type && entry.task_type.name}</td>
                <td>{format_dt(entry.started_at)}</td>
                <td>{format_dt(entry.ended_at)}</td>
                <td>{format_duration(entry)}</td>
                <td>{entry.notes}</td>
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

  defp format_dt(nil), do: "—"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  defp format_duration(%{duration_seconds: secs}) when is_integer(secs) do
    h = div(secs, 3600)
    m = div(rem(secs, 3600), 60)
    s = rem(secs, 60)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> to_string()
  end

  defp format_duration(%{started_at: %DateTime{} = started_at, ended_at: nil}) do
    secs = DateTime.diff(DateTime.utc_now(), started_at, :second)
    format_duration(%{duration_seconds: secs})
  end

  defp format_duration(_), do: "—"
end
