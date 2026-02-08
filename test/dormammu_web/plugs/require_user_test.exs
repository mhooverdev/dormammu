defmodule DormammuWeb.Plugs.RequireUserTest do
  use DormammuWeb.ConnCase

  alias DormammuWeb.Plugs.RequireUser
  alias Dormammu.Accounts.User

  test "allows request when user is present", %{conn: conn} do
    user = insert_user()

    conn =
      conn
      |> assign(:current_user, user)
      |> RequireUser.call([])

    assert conn.halted == false
    assert conn.assigns.current_user.id == user.id
  end

  test "redirects and halts when no user", %{conn: conn} do
    conn =
      conn
      |> fetch_flash()
      |> assign(:current_user, nil)
      |> RequireUser.call([])

    assert conn.halted == true
    assert redirected_to(conn) == ~p"/login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Please log in to continue"
  end

  # Helper function
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
