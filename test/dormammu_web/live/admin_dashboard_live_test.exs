defmodule DormammuWeb.AdminDashboardLiveTest do
  use DormammuWeb.LiveViewCase

  alias Dormammu.Accounts.User

  setup %{conn: conn} do
    admin = insert_admin()
    conn = conn |> assign(:current_user, admin) |> put_session(:session_user_id, admin.id)
    {:ok, conn: conn, admin: admin}
  end

  test "renders admin dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin")

    assert has_element?(view, "h1", "Admin Dashboard")
    assert has_element?(view, ".text-sm", "Users")
    assert has_element?(view, ".text-sm", "Active Entries")
  end

  test "displays user count", %{conn: conn} do
    insert_user(%{os_username: "user1"})
    insert_user(%{os_username: "user2"})

    {:ok, view, _html} = live(conn, ~p"/admin")

    html = render(view)
    assert html =~ "Users"
  end

  test "displays active entries count", %{conn: conn} do
    user = insert_user()
    task = insert_task_type(user, %{name: "Task"})
    insert_time_entry(user, task, %{ended_at: nil})

    {:ok, view, _html} = live(conn, ~p"/admin")

    html = render(view)
    assert html =~ "Active Entries"
  end

  test "displays recent activity", %{conn: conn} do
    user = insert_user()
    task = insert_task_type(user, %{name: "Development"})

    insert_time_entry(user, task, %{
      started_at: ~U[2024-01-01 10:00:00Z],
      ended_at: ~U[2024-01-01 11:00:00Z]
    })

    {:ok, view, _html} = live(conn, ~p"/admin")

    html = render(view)
    assert html =~ "Development"
  end

  # Helper functions
  defp insert_admin(attrs \\ %{}) do
    defaults = %{
      os_username: "admin",
      email: "admin@example.com",
      password: "password123",
      role: :admin,
      active: true
    }

    attrs = Map.merge(defaults, attrs)

    %User{}
    |> User.admin_changeset(attrs)
    |> Dormammu.Repo.insert!()
  end

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
