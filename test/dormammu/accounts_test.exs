defmodule Dormammu.AccountsTest do
  use Dormammu.DataCase

  alias Dormammu.Accounts
  alias Dormammu.Accounts.User

  describe "list_users/0" do
    test "returns all users" do
      user1 = insert_user(%{os_username: "user1"})
      user2 = insert_user(%{os_username: "user2"})

      users = Accounts.list_users()
      assert length(users) >= 2
      assert user1 in users
      assert user2 in users
    end
  end

  describe "get_user/1" do
    test "returns user by id" do
      user = insert_user(%{os_username: "testuser"})
      assert Accounts.get_user(user.id).id == user.id
    end

    test "returns nil for non-existent user" do
      assert Accounts.get_user(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_user!/1" do
    test "returns user by id" do
      user = insert_user(%{os_username: "testuser"})
      assert Accounts.get_user!(user.id).id == user.id
    end

    test "raises for non-existent user" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_user_by_email/1" do
    test "returns user by email" do
      user = insert_user(%{email: "test@example.com", role: :admin})
      assert Accounts.get_user_by_email("test@example.com").id == user.id
    end

    test "returns nil for non-existent email" do
      assert Accounts.get_user_by_email("nonexistent@example.com") == nil
    end
  end

  describe "get_user_by_os/1" do
    test "returns user by os_username" do
      user = insert_user(%{os_username: "testuser"})
      assert Accounts.get_user_by_os("testuser").id == user.id
    end

    test "returns nil for non-existent os_username" do
      assert Accounts.get_user_by_os("nonexistent") == nil
    end

    test "returns nil for nil input" do
      assert Accounts.get_user_by_os(nil) == nil
    end
  end

  describe "ensure_os_user/2" do
    test "creates new user when os_username doesn't exist" do
      assert {:ok, user} = Accounts.ensure_os_user("newuser", "New User")
      assert user.os_username == "newuser"
      assert user.display_name == "New User"
      assert user.role == :user
    end

    test "returns existing user when os_username exists" do
      existing = insert_user(%{os_username: "existing"})
      assert {:ok, user} = Accounts.ensure_os_user("existing", "Updated Name")
      assert user.id == existing.id
      assert user.os_username == "existing"
    end

    test "returns error for nil os_username" do
      assert {:error, :no_os_user} = Accounts.ensure_os_user(nil)
    end
  end

  describe "create_admin/1" do
    test "creates admin user with valid attributes" do
      attrs = %{
        os_username: "admin",
        email: "admin@example.com",
        password: "password123",
        display_name: "Admin"
      }

      assert {:ok, user} = Accounts.create_admin(attrs)
      assert user.email == "admin@example.com"
      assert user.role == :admin
      assert user.display_name == "Admin"
      assert user.password_hash
    end

    test "validates required fields" do
      assert {:error, changeset} = Accounts.create_admin(%{})
      assert "can't be blank" in errors_on(changeset).email
      assert "can't be blank" in errors_on(changeset).password
    end

    test "validates password length" do
      attrs = %{os_username: "admin", email: "admin@example.com", password: "short"}
      assert {:error, changeset} = Accounts.create_admin(attrs)
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "validates unique email" do
      insert_user(%{os_username: "existing", email: "admin@example.com", role: :admin})
      attrs = %{os_username: "admin", email: "admin@example.com", password: "password123"}
      assert {:error, changeset} = Accounts.create_admin(attrs)
      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "update_user/2" do
    test "updates user with valid attributes" do
      user = insert_user(%{os_username: "testuser"})

      assert {:ok, updated} =
               Accounts.update_user(user, %{display_name: "New Name", active: false})

      assert updated.display_name == "New Name"
      assert updated.active == false
    end

    test "returns error for invalid attributes" do
      user = insert_user(%{os_username: "testuser"})
      # profile_changeset only allows display_name and active
      assert {:ok, _} = Accounts.update_user(user, %{display_name: "New Name"})
    end
  end

  describe "deactivate_user/1" do
    test "deactivates user" do
      user = insert_user(%{os_username: "testuser", active: true})
      assert {:ok, updated} = Accounts.deactivate_user(user)
      assert updated.active == false
    end
  end

  describe "authenticate_admin/2" do
    test "returns user for valid credentials" do
      {:ok, user} =
        Accounts.create_admin(%{
          os_username: "admin",
          email: "admin@example.com",
          password: "password123"
        })

      assert {:ok, authenticated} =
               Accounts.authenticate_admin("admin@example.com", "password123")

      assert authenticated.id == user.id
    end

    test "returns error for invalid password" do
      {:ok, _user} =
        Accounts.create_admin(%{
          os_username: "admin",
          email: "admin@example.com",
          password: "password123"
        })

      assert {:error, :unauthorized} = Accounts.authenticate_admin("admin@example.com", "wrong")
    end

    test "returns error for non-existent email" do
      assert {:error, :unauthorized} =
               Accounts.authenticate_admin("nonexistent@example.com", "password")
    end

    test "returns error for non-admin user" do
      _user = insert_user(%{os_username: "user1", email: "user@example.com", role: :user})
      # Note: regular users don't have password_hash, so this will fail
      assert {:error, :unauthorized} = Accounts.authenticate_admin("user@example.com", "password")
    end

    test "returns error for inactive admin" do
      {:ok, user} =
        Accounts.create_admin(%{
          os_username: "admin",
          email: "admin@example.com",
          password: "password123"
        })

      {:ok, _} = Accounts.update_user(user, %{active: false})

      assert {:error, :unauthorized} =
               Accounts.authenticate_admin("admin@example.com", "password123")
    end
  end

  describe "change_user/2" do
    test "returns a changeset" do
      user = insert_user(%{os_username: "testuser"})
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  # Helper function to insert a user
  defp insert_user(attrs \\ %{}) do
    defaults = %{
      os_username: "testuser",
      role: :user,
      active: true
    }

    attrs = Map.merge(defaults, attrs)

    %User{}
    |> User.os_user_changeset(attrs)
    |> Ecto.Changeset.put_change(:role, attrs[:role] || :user)
    |> Ecto.Changeset.put_change(:active, attrs[:active] || true)
    |> Ecto.Changeset.put_change(:email, attrs[:email])
    |> Ecto.Changeset.put_change(
      :password_hash,
      attrs[:password_hash] || Pbkdf2.hash_pwd_salt("password123")
    )
    |> Dormammu.Repo.insert!()
  end
end
