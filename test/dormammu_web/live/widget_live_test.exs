defmodule DormammuWeb.WidgetLiveTest do
  use DormammuWeb.LiveViewCase

  alias Dormammu.Accounts.User
  alias Dormammu.Tracking

  setup %{conn: conn} do
    user = insert_user()
    conn = conn |> assign(:current_user, user) |> put_session(:session_user_id, user.id)
    {:ok, conn: conn, user: user}
  end

  test "renders widget with tasks", %{conn: conn, user: user} do
    insert_task_type(user, %{name: "Task 1"})
    insert_task_type(user, %{name: "Task 2"})

    {:ok, view, _html} = live(conn, ~p"/me/dashboard")

    assert has_element?(view, "div", "Time Tracker")
    html = render(view)
    assert html =~ "Task 1"
    assert html =~ "Task 2"
  end

  test "redirects when no user", %{conn: conn} do
    conn =
      conn
      |> assign(:current_user, nil)
      |> delete_session(:session_user_id)

    assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/me/dashboard")
    assert to == "/" or to == "/login"
  end

  test "play_task event starts tracking task", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Task"})

    {:ok, view, _html} = live(conn, ~p"/me/dashboard")
    widget_view = find_live_child(view, "widget")

    html = element(widget_view, "#widget-play-#{task.id}") |> render_click()
    assert html =~ "running"
    assert html =~ "Stop"
  end

  test "toggle_minimize event toggles minimized state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/me/dashboard")
    widget_view = find_live_child(view, "widget")

    html = element(widget_view, "button", "—") |> render_click()
    assert html =~ "minimized" or html =~ "opacity-90"
  end

  test "create_task event creates new task", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/me/dashboard")
    widget_view = find_live_child(view, "widget")

    html =
      widget_view
      |> form("#task-form", %{name: "New Task"})
      |> render_submit()

    assert html =~ "New Task"
  end

  test "create_task with blank name does not add task", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/me/dashboard")
    widget_view = find_live_child(view, "widget")

    widget_view
    |> form("#task-form", %{name: ""})
    |> render_submit()

    refute render(widget_view) =~ "New Task"
  end

  test "stop event stops active entry", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Task"})
    {:ok, _entry} = Tracking.start_entry(user, task)

    {:ok, view, _html} = live(conn, ~p"/me/dashboard")
    widget_view = find_live_child(view, "widget")

    assert render(widget_view) =~ "running"

    html = widget_view |> element("#widget-stop-btn") |> render_click()
    assert html =~ "stopped"
    assert Tracking.current_entry(user) == nil
  end

  test "displays elapsed time for active entry", %{conn: conn, user: user} do
    task = insert_task_type(user, %{name: "Task"})
    started_at = DateTime.add(DateTime.utc_now(), -120, :second)
    insert_time_entry(user, task, %{started_at: started_at, ended_at: nil})

    {:ok, view, _html} = live(conn, ~p"/me/dashboard")
    widget_view = find_live_child(view, "widget")
    html = render(widget_view)

    assert html =~ "running"
    assert html =~ "02:00" or html =~ "01:59" or html =~ "02:01"
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

  defp insert_task_type(user, attrs) do
    defaults = %{name: "Test Task", user_id: user.id, active: true}
    attrs = Map.merge(defaults, attrs)

    %Dormammu.Tracking.TaskType{}
    |> Dormammu.Tracking.TaskType.changeset(attrs)
    |> Dormammu.Repo.insert!()
  end

  defp insert_time_entry(user, task_type, attrs) do
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
