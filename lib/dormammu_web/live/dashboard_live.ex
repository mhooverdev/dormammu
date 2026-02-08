defmodule DormammuWeb.DashboardLive do
  @moduledoc """
  User self dashboard with simple summaries.
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
     |> assign(:totals, totals(entries))
     |> assign(:page_title, "Dashboard")}
  end

  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: "/")}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold">My Dashboard</h1>
          <p class="text-sm opacity-70">Quick summary of your tracked time.</p>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Today</div>
          <div class="text-2xl font-bold">{format_secs(@totals.today)}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">This Week</div>
          <div class="text-2xl font-bold">{format_secs(@totals.week)}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">All Time</div>
          <div class="text-2xl font-bold">{format_secs(@totals.all_time)}</div>
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

  defp totals(entries) do
    now = DateTime.utc_now()
    today = Date.utc_today()
    week = Date.beginning_of_week(today)

    Enum.reduce(entries, %{today: 0, week: 0, all_time: 0}, fn entry, acc ->
      duration = entry_duration(entry, now)
      date = DateTime.to_date(entry.started_at)

      acc
      |> Map.update!(:all_time, &(&1 + duration))
      |> maybe_add(:today, duration, date == today)
      |> maybe_add(:week, duration, Date.compare(date, week) != :lt)
    end)
  end

  defp maybe_add(acc, key, duration, true), do: Map.update!(acc, key, &(&1 + duration))
  defp maybe_add(acc, _key, _duration, false), do: acc

  defp entry_duration(%{duration_seconds: secs}, _) when is_integer(secs), do: secs

  defp entry_duration(%{started_at: start, ended_at: nil}, now),
    do: DateTime.diff(now, start, :second)

  defp entry_duration(_, _), do: 0

  defp format_secs(secs) do
    h = div(secs, 3600)
    m = div(rem(secs, 3600), 60)
    "#{h}h #{m}m"
  end
end
