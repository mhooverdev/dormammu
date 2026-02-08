defmodule DormammuWeb.AdminReportsLive do
  @moduledoc """
  Admin reports view with basic listings.
  """
  use DormammuWeb, :live_view

  alias Dormammu.Tracking

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")
     |> assign(:date_from, nil)
     |> assign(:date_to, nil)
     |> assign(:limit, 100)
     |> assign(:entries, [])
     |> assign(
       :filter_form,
       to_form(%{"date_from" => "", "date_to" => "", "limit" => "100"}, as: "filter")
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = filter_params(params)
    entries = load_entries(filter)

    form_values = %{
      "date_from" => filter[:date_from] && Date.to_iso8601(filter[:date_from]),
      "date_to" => filter[:date_to] && Date.to_iso8601(filter[:date_to]),
      "limit" => limit_for_form(filter[:limit] || 100)
    }

    filter_form = to_form(form_values, as: "filter")

    {:noreply,
     socket
     |> assign(:date_from, filter[:date_from])
     |> assign(:date_to, filter[:date_to])
     |> assign(:limit, filter[:limit])
     |> assign(:entries, entries)
     |> assign(:filter_form, filter_form)}
  end

  @impl true
  def handle_event("apply_filters", %{"filter" => params}, socket) do
    path = reports_path(params)
    {:noreply, push_patch(socket, to: path)}
  end

  defp filter_params(params) do
    # Support both nested filter[date_from] and top-level from handle_params
    raw = params["filter"] || params

    %{
      date_from: parse_date(raw["date_from"]),
      date_to: parse_date(raw["date_to"]),
      limit: parse_limit(raw["limit"])
    }
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp parse_limit("all"), do: :all
  defp parse_limit(_), do: 100

  defp limit_for_form(:all), do: "all"
  defp limit_for_form(n), do: to_string(n)

  defp load_entries(filter) do
    opts = []

    opts =
      if filter[:date_from], do: Keyword.put(opts, :date_from, filter[:date_from]), else: opts

    opts = if filter[:date_to], do: Keyword.put(opts, :date_to, filter[:date_to]), else: opts
    opts = Keyword.put(opts, :limit, filter[:limit] || 100)
    Tracking.list_entries_all(opts)
  end

  defp reports_path(params) do
    q =
      []
      |> maybe_put(:date_from, params["date_from"])
      |> maybe_put(:date_to, params["date_to"])
      |> maybe_put(:limit, params["limit"])

    case q do
      [] -> ~p"/admin/reports"
      _ -> ~p"/admin/reports" <> "?" <> URI.encode_query(q)
    end
  end

  defp maybe_put(acc, _key, nil), do: acc
  defp maybe_put(acc, _key, ""), do: acc
  defp maybe_put(acc, key, val), do: Keyword.put(acc, key, val)

  defp export_csv_url(assigns) do
    q =
      []
      |> maybe_put(:date_from, assigns[:date_from] && Date.to_iso8601(assigns.date_from))
      |> maybe_put(:date_to, assigns[:date_to] && Date.to_iso8601(assigns.date_to))
      |> maybe_put(:limit, (assigns[:limit] == :all && "all") || "100")

    url = ~p"/admin/reports/export.csv"

    case q do
      [] -> url
      _ -> "#{url}?#{URI.encode_query(q)}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-6xl space-y-4 px-4 sm:px-6 lg:px-10">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight">Reports</h1>
          <p class="text-sm opacity-70">
            <%= if @limit == :all do %>
              All entries across all users.
            <% else %>
              Latest {@limit} entries across all users.
            <% end %>
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <.link href={export_csv_url(assigns)} class="btn btn-primary btn-sm">
            <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Export CSV
          </.link>
          <.link navigate={~p"/admin"} class="btn btn-outline btn-sm">Back</.link>
        </div>
      </div>

      <.form
        for={@filter_form}
        id="reports-filter-form"
        phx-change="apply_filters"
        class="flex flex-wrap items-end gap-4 p-4 rounded-lg bg-base-200/50"
      >
        <div class="form-control">
          <.input
            field={@filter_form[:date_from]}
            type="date"
            label="From"
            class="input-sm"
          />
        </div>
        <div class="form-control">
          <.input
            field={@filter_form[:date_to]}
            type="date"
            label="To"
            class="input-sm"
          />
        </div>
        <div class="form-control">
          <.input
            field={@filter_form[:limit]}
            type="select"
            label="Records"
            options={[{"Latest 100", "100"}, {"All records", "all"}]}
            class="select-sm"
          />
        </div>
      </.form>

      <div class="overflow-x-auto">
        <table class="table table-sm table-zebra">
          <thead>
            <tr>
              <th>User</th>
              <th>Task</th>
              <th>Start</th>
              <th>End</th>
              <th>Duration (s)</th>
            </tr>
          </thead>
          <tbody>
            <%= for e <- @entries do %>
              <tr>
                <td>{user_name(e.user)}</td>
                <td>{e.task_type && e.task_type.name}</td>
                <td>{fmt(e.started_at)}</td>
                <td>{fmt(e.ended_at)}</td>
                <td>{e.duration_seconds || "—"}</td>
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

  defp user_name(nil), do: "Unknown"
  defp user_name(u), do: u.display_name || u.os_username || u.email || "User"
  defp fmt(nil), do: "—"
  defp fmt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
