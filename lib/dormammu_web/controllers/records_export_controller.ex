defmodule DormammuWeb.RecordsExportController do
  use DormammuWeb, :controller

  alias Dormammu.Tracking

  def export(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> text("unauthorized")

      user ->
        csv = Tracking.export_entries_csv(user)

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", ~s(attachment; filename="time_entries.csv"))
        |> send_resp(:ok, csv)
    end
  end
end
