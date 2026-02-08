defmodule DormammuWeb.Plugs.RequireAdminTest do
  use DormammuWeb.ConnCase

  alias DormammuWeb.Plugs.RequireAdmin
  alias Dormammu.Accounts.User

  test "allows request when admin user is present", %{conn: conn} do
    admin = insert_admin()

    conn =
      conn
      |> assign(:current_user, admin)
      |> RequireAdmin.call([])

    assert conn.halted == false
    assert conn.assigns.current_user.id == admin.id
  end

  test "redirects and halts when no user", %{conn: conn} do
    conn =
      conn
      |> fetch_flash()
      |> assign(:current_user, nil)
      |> RequireAdmin.call([])

    assert conn.halted == true
    assert redirected_to(conn) == ~p"/login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Admin access required"
  end

  test "redirects and halts when user is not admin", %{conn: conn} do
    user = insert_user()

    conn =
      conn
      |> fetch_flash()
      |> assign(:current_user, user)
      |> RequireAdmin.call([])

    assert conn.halted == true
    assert redirected_to(conn) == ~p"/login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Admin access required"
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
end
