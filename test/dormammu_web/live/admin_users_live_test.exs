defmodule DormammuWeb.AdminUsersLiveTest do
  use DormammuWeb.LiveViewCase

  alias Dormammu.Accounts
  alias Dormammu.Accounts.User

  setup %{conn: conn} do
    admin = insert_admin()
    conn = conn |> assign(:current_user, admin) |> put_session(:session_user_id, admin.id)
    {:ok, conn: conn, admin: admin}
  end

  test "renders users page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/users")

    assert has_element?(view, "h1", "Users")
  end

  test "displays all users", %{conn: conn} do
    user1 = insert_user(%{os_username: "user1", email: "user1@example.com"})
    user2 = insert_user(%{os_username: "user2", email: "user2@example.com"})

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    html = render(view)
    assert html =~ "user1"
    assert html =~ "user2"
  end

  test "toggle event activates inactive user", %{conn: conn} do
    user = insert_user(%{os_username: "user1", active: false})

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    view
    |> element("button[phx-click='toggle'][phx-value-id='#{user.id}']")
    |> render_click()

    updated = Accounts.get_user(user.id)
    assert updated.active == true
  end

  test "toggle event deactivates active user", %{conn: conn} do
    user = insert_user(%{os_username: "user1", active: true})

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    view
    |> element("button[phx-click='toggle'][phx-value-id='#{user.id}']")
    |> render_click()

    updated = Accounts.get_user(user.id)
    assert updated.active == false
  end

  test "displays user role", %{conn: conn} do
    user = insert_user(%{os_username: "user1", role: :user})
    admin = insert_admin(%{os_username: "admin2", email: "admin2@example.com"})

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    html = render(view)
    assert html =~ "user"
    assert html =~ "admin"
  end

  test "displays user status", %{conn: conn} do
    active_user = insert_user(%{os_username: "active", active: true})
    inactive_user = insert_user(%{os_username: "inactive", active: false})

    {:ok, view, _html} = live(conn, ~p"/admin/users")

    html = render(view)
    assert html =~ "Active"
    assert html =~ "Inactive"
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
    |> Ecto.Changeset.put_change(:active, Map.get(attrs, :active, true))
    |> Ecto.Changeset.put_change(:email, attrs[:email])
    |> Ecto.Changeset.put_change(:password_hash, Pbkdf2.hash_pwd_salt("password123"))
    |> Dormammu.Repo.insert!()
  end
end
