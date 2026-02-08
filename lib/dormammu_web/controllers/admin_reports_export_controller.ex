defmodule DormammuWeb.AdminReportsExportController do
  use DormammuWeb, :controller

  alias Dormammu.Tracking

  def export(conn, params) do
    opts = parse_export_opts(params)
    csv = Tracking.export_entries_all_csv(opts)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="admin_reports.csv"))
    |> send_resp(:ok, csv)
  end

  defp parse_export_opts(params) do
    opts = []

    opts =
      case params["date_from"] do
        nil ->
          opts

        "" ->
          opts

        str ->
          case Date.from_iso8601(str) do
            {:ok, d} -> Keyword.put(opts, :date_from, d)
            _ -> opts
          end
      end

    opts =
      case params["date_to"] do
        nil ->
          opts

        "" ->
          opts

        str ->
          case Date.from_iso8601(str) do
            {:ok, d} -> Keyword.put(opts, :date_to, d)
            _ -> opts
          end
      end

    opts =
      case params["limit"] do
        "all" -> Keyword.put(opts, :limit, :all)
        _ -> Keyword.put(opts, :limit, 100)
      end

    opts
  end
end
