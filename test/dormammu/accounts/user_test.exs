defmodule Dormammu.Accounts.UserTest do
  use Dormammu.DataCase

  alias Dormammu.Accounts.User

  describe "os_user_changeset/2" do
    test "valid changeset" do
      attrs = %{os_username: "testuser", display_name: "Test User"}
      changeset = User.os_user_changeset(%User{}, attrs)

      assert changeset.valid?
      assert changeset.changes.os_username == "testuser"
      assert changeset.changes.display_name == "Test User"
    end

    test "requires os_username" do
      changeset = User.os_user_changeset(%User{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).os_username
    end

    test "validates unique os_username" do
      %User{}
      |> User.os_user_changeset(%{os_username: "testuser"})
      |> Dormammu.Repo.insert!()

      changeset =
        %User{}
        |> User.os_user_changeset(%{os_username: "testuser"})
        |> Dormammu.Repo.insert()

      assert {:error, changeset} = changeset
      assert "has already been taken" in errors_on(changeset).os_username
    end
  end

  describe "admin_changeset/2" do
    test "valid changeset" do
      attrs = %{
        os_username: "admin",
        email: "admin@example.com",
        password: "password123",
        role: :admin,
        display_name: "Admin User"
      }

      changeset = User.admin_changeset(%User{}, attrs)

      assert changeset.valid?
      assert changeset.changes.email == "admin@example.com"
      assert changeset.changes.role == :admin
      assert changeset.changes.password_hash
    end

    test "requires email" do
      changeset =
        User.admin_changeset(%User{}, %{
          os_username: "admin",
          password: "password123",
          role: :admin
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).email
    end

    test "requires password" do
      changeset =
        User.admin_changeset(%User{}, %{
          os_username: "admin",
          email: "admin@example.com",
          role: :admin
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).password
    end

    test "requires role" do
      changeset =
        User.admin_changeset(%User{}, %{
          os_username: "admin",
          email: "admin@example.com",
          password: "password123",
          role: nil
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "validates password length" do
      changeset =
        User.admin_changeset(%User{}, %{
          os_username: "admin",
          email: "admin@example.com",
          password: "short",
          role: :admin
        })

      refute changeset.valid?
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end

    test "validates role inclusion" do
      changeset =
        User.admin_changeset(%User{}, %{
          os_username: "admin",
          email: "admin@example.com",
          password: "password123",
          role: :invalid_role
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "validates unique email" do
      %User{}
      |> User.admin_changeset(%{
        os_username: "admin",
        email: "admin@example.com",
        password: "password123",
        role: :admin
      })
      |> Dormammu.Repo.insert!()

      changeset =
        %User{}
        |> User.admin_changeset(%{
          os_username: "admin2",
          email: "admin@example.com",
          password: "password123",
          role: :admin
        })
        |> Dormammu.Repo.insert()

      assert {:error, changeset} = changeset
      assert "has already been taken" in errors_on(changeset).email
    end

    test "hashes password" do
      attrs = %{
        os_username: "admin",
        email: "admin@example.com",
        password: "password123",
        role: :admin
      }

      changeset = User.admin_changeset(%User{}, attrs)

      assert changeset.changes.password_hash
      refute changeset.changes.password_hash == "password123"
    end
  end

  describe "profile_changeset/2" do
    test "valid changeset" do
      user = %User{id: Ecto.UUID.generate()}
      attrs = %{display_name: "New Name", active: false}
      changeset = User.profile_changeset(user, attrs)

      assert changeset.valid?
      assert changeset.changes.display_name == "New Name"
      assert changeset.changes.active == false
    end

    test "allows partial updates" do
      user = %User{id: Ecto.UUID.generate()}
      changeset = User.profile_changeset(user, %{display_name: "New Name"})

      assert changeset.valid?
      assert changeset.changes.display_name == "New Name"
    end
  end
end
