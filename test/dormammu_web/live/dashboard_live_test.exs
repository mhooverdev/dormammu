defmodule DormammuWeb.DashboardLiveTest do
  use DormammuWeb.LiveViewCase

  alias Dormammu.{Accounts, Tracking}
  alias Dormammu.Accounts.User

  setup %{conn: conn} do
    user = insert_user()
    conn = conn |> assign(:current_user, user) |> put_session(:session_user_id, user.id)
    {:ok, conn: conn, user: user}
  end

  test "renders dashboard with user entries", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Development"})
    now = DateTime.utc_now()
    today = Date.utc_today()
    week_start = Date.beginning_of_week(today)

    # Entry from today
    insert_time_entry(user, task, %{
      started_at: DateTime.new!(today, ~T[10:00:00], "Etc/UTC"),
      ended_at: DateTime.new!(today, ~T[11:00:00], "Etc/UTC"),
      duration_seconds: 3600
    })

    # Entry from this week
    week_date = Date.add(week_start, 1)

    insert_time_entry(user, task, %{
      started_at: DateTime.new!(week_date, ~T[10:00:00], "Etc/UTC"),
      ended_at: DateTime.new!(week_date, ~T[12:00:00], "Etc/UTC"),
      duration_seconds: 7200
    })

    # Old entry
    old_date = Date.add(today, -10)

    insert_time_entry(user, task, %{
      started_at: DateTime.new!(old_date, ~T[10:00:00], "Etc/UTC"),
      ended_at: DateTime.new!(old_date, ~T[11:00:00], "Etc/UTC"),
      duration_seconds: 3600
    })

    {:ok, view, _html} = live(conn, ~p"/me/dashboard")

    assert has_element?(view, "h1", "My Dashboard")
    assert has_element?(view, ".text-sm", "Today")
    assert has_element?(view, ".text-sm", "This Week")
    assert has_element?(view, ".text-sm", "All Time")
  end

  test "redirects when no user", %{conn: conn} do
    conn = conn |> assign(:current_user, nil) |> delete_session(:session_user_id)
    assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/me/dashboard")
    assert to == "/" or to == "/login"
  end

  test "displays totals correctly", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Development"})
    today = Date.utc_today()

    insert_time_entry(user, task, %{
      started_at: DateTime.new!(today, ~T[10:00:00], "Etc/UTC"),
      ended_at: DateTime.new!(today, ~T[11:00:00], "Etc/UTC"),
      duration_seconds: 3600
    })

    {:ok, view, _html} = live(conn, ~p"/me/dashboard")

    html = render(view)
    assert html =~ "1h"
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
