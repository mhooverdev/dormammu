defmodule Dormammu.Tracking.TaskTypeTest do
  use Dormammu.DataCase

  alias Dormammu.Tracking.TaskType
  alias Dormammu.Accounts.User

  describe "changeset/2" do
    test "valid changeset" do
      user = insert_user()
      attrs = %{name: "Development", color: "#FF0000", position: 1, user_id: user.id}
      changeset = TaskType.changeset(%TaskType{}, attrs)

      assert changeset.valid?
      assert changeset.changes.name == "Development"
      assert changeset.changes.user_id == user.id
    end

    test "requires name" do
      user = insert_user()
      changeset = TaskType.changeset(%TaskType{}, %{user_id: user.id})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires user_id" do
      changeset = TaskType.changeset(%TaskType{}, %{name: "Development"})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "validates unique name per user" do
      user = insert_user()

      %TaskType{}
      |> TaskType.changeset(%{name: "Development", user_id: user.id})
      |> Dormammu.Repo.insert!()

      changeset =
        %TaskType{}
        |> TaskType.changeset(%{name: "Development", user_id: user.id})
        |> Dormammu.Repo.insert()

      assert {:error, changeset} = changeset
      assert "has already been taken" in errors_on(changeset).name
    end

    test "allows same name for different users" do
      user1 = insert_user()
      user2 = insert_user(%{os_username: "user2"})

      %TaskType{}
      |> TaskType.changeset(%{name: "Development", user_id: user1.id})
      |> Dormammu.Repo.insert!()

      assert {:ok, _} =
               %TaskType{}
               |> TaskType.changeset(%{name: "Development", user_id: user2.id})
               |> Dormammu.Repo.insert()
    end
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
