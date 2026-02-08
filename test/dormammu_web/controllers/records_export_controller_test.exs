defmodule DormammuWeb.RecordsExportControllerTest do
  use DormammuWeb.ConnCase

  alias Dormammu.Accounts.User

  setup %{conn: conn} do
    user = insert_user()
    conn = conn |> put_session(:session_user_id, user.id)
    {:ok, conn: conn, user: user}
  end

  test "GET /me/records/export.csv with authenticated user", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Development"})

    insert_time_entry(user, task, %{
      started_at: ~U[2024-01-01 10:00:00Z],
      ended_at: ~U[2024-01-01 11:00:00Z],
      duration_seconds: 3600,
      notes: "Test notes"
    })

    conn = get(conn, ~p"/me/records/export.csv")

    assert response_content_type(conn, :csv) =~ "text/csv"

    assert [content_disp | _] = get_resp_header(conn, "content-disposition")
    assert content_disp =~ ~s(attachment; filename="time_entries.csv")

    assert response(conn, 200) =~ "task,start,end,duration_seconds,notes"
    assert response(conn, 200) =~ "Development"
    assert response(conn, 200) =~ "3600"
    assert response(conn, 200) =~ "Test notes"
  end

  test "GET /me/records/export.csv without user redirects to login", %{conn: conn} do
    conn = conn |> delete_session(:session_user_id)
    conn = get(conn, ~p"/me/records/export.csv")

    assert redirected_to(conn) == ~p"/login"
  end

  test "GET /me/records/export.csv with empty entries", %{conn: conn} do
    conn = get(conn, ~p"/me/records/export.csv")

    assert response_content_type(conn, :csv) =~ "text/csv"
    assert response(conn, 200) =~ "task,start,end,duration_seconds,notes"
  end

  # Helper functions
  defp insert_user(attrs \\ %{}) do
    defaults = %{os_username: "testuser", role: :user, active: true}
    attrs = Map.merge(defaults, attrs)

    %User{}
    |> User.os_user_changeset(attrs)
    |> Ecto.Changeset.put_change(:role, attrs[:role] || :user)
    |> Ecto.Changeset.put_change(:active, attrs[:active] || true)
    |> Ecto.Changeset.put_change(:email, attrs[:email])
    |> Ecto.Changeset.put_change(:password_hash, Pbkdf2.hash_pwd_salt("password123"))
    |> Dormammu.Repo.insert!()
  end

  defp insert_task_type(user, attrs \\ %{}) do
    defaults = %{name: "Test Task", user_id: user.id, active: true}
    attrs = Map.merge(defaults, attrs)

    %Dormammu.Tracking.TaskType{}
    |> Dormammu.Tracking.TaskType.changeset(attrs)
    |> Dormammu.Repo.insert!()
  end

  defp insert_time_entry(user, task_type, attrs \\ %{}) do
    now = DateTime.utc_now()

    defaults = %{
      user_id: user.id,
      task_type_id: task_type.id,
      started_at: DateTime.add(now, -3600, :second),
      ended_at: now,
      duration_seconds: 3600,
      source: "test"
    }

    attrs = Map.merge(defaults, attrs)

    %Dormammu.Tracking.TimeEntry{}
    |> Dormammu.Tracking.TimeEntry.changeset(attrs)
    |> Dormammu.Repo.insert!()
  end
end
