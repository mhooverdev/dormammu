defmodule DormammuWeb.RecordsLiveTest do
  use DormammuWeb.LiveViewCase

  alias Dormammu.Accounts.User

  setup %{conn: conn} do
    user = insert_user()
    conn = conn |> assign(:current_user, user) |> put_session(:session_user_id, user.id)
    {:ok, conn: conn, user: user}
  end

  test "renders records page with entries", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Development"})

    insert_time_entry(user, task, %{
      started_at: ~U[2024-01-01 10:00:00Z],
      ended_at: ~U[2024-01-01 11:00:00Z],
      duration_seconds: 3600,
      notes: "Test notes"
    })

    {:ok, view, _html} = live(conn, ~p"/me/records")

    assert has_element?(view, "h1", "My Time Records")
    assert render(view) =~ "Development"
    assert render(view) =~ "Test notes"
  end

  test "redirects when no user", %{conn: conn} do
    conn = conn |> assign(:current_user, nil) |> delete_session(:session_user_id)
    assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/me/records")
    assert to == "/" or to == "/login"
  end

  test "refresh event updates entries", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Development"})
    {:ok, view, _html} = live(conn, ~p"/me/records")

    insert_time_entry(user, task, %{
      started_at: ~U[2024-01-01 10:00:00Z],
      ended_at: ~U[2024-01-01 11:00:00Z],
      duration_seconds: 3600
    })

    html = element(view, "button", "Refresh") |> render_click()

    assert html =~ "Development"
  end

  test "displays export link", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/me/records")

    assert has_element?(view, "a[href='/me/records/export.csv']", "Export CSV")
  end

  test "formats duration correctly", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Development"})

    insert_time_entry(user, task, %{
      started_at: ~U[2024-01-01 10:00:00Z],
      ended_at: ~U[2024-01-01 11:30:45Z],
      duration_seconds: 5445
    })

    {:ok, view, _html} = live(conn, ~p"/me/records")

    html = render(view)
    assert html =~ "01:30:45"
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
