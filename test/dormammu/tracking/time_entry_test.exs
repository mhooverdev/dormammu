defmodule Dormammu.Tracking.TimeEntryTest do
  use Dormammu.DataCase

  alias Dormammu.Tracking.TimeEntry
  alias Dormammu.Accounts.User
  alias Dormammu.Tracking.TaskType

  describe "changeset/2" do
    test "valid changeset" do
      user = insert_user()
      task = insert_task_type(user)

      attrs = %{
        user_id: user.id,
        task_type_id: task.id,
        started_at: ~U[2024-01-01 10:00:00Z],
        ended_at: ~U[2024-01-01 11:00:00Z],
        duration_seconds: 3600,
        notes: "Test notes",
        source: "widget"
      }

      changeset = TimeEntry.changeset(%TimeEntry{}, attrs)

      assert changeset.valid?
      assert changeset.changes.user_id == user.id
      assert changeset.changes.task_type_id == task.id
    end

    test "requires started_at" do
      user = insert_user()
      task = insert_task_type(user)

      changeset =
        TimeEntry.changeset(%TimeEntry{}, %{
          user_id: user.id,
          task_type_id: task.id
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).started_at
    end

    test "requires user_id" do
      user = insert_user()
      task = insert_task_type(user)

      changeset =
        TimeEntry.changeset(%TimeEntry{}, %{
          task_type_id: task.id,
          started_at: ~U[2024-01-01 10:00:00Z]
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "requires task_type_id" do
      user = insert_user()

      changeset =
        TimeEntry.changeset(%TimeEntry{}, %{
          user_id: user.id,
          started_at: ~U[2024-01-01 10:00:00Z]
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).task_type_id
    end

    test "allows nil ended_at for active entries" do
      user = insert_user()
      task = insert_task_type(user)

      attrs = %{
        user_id: user.id,
        task_type_id: task.id,
        started_at: ~U[2024-01-01 10:00:00Z],
        ended_at: nil
      }

      changeset = TimeEntry.changeset(%TimeEntry{}, attrs)

      assert changeset.valid?
    end

    test "allows optional fields" do
      user = insert_user()
      task = insert_task_type(user)

      attrs = %{
        user_id: user.id,
        task_type_id: task.id,
        started_at: ~U[2024-01-01 10:00:00Z],
        notes: "Optional notes",
        source: "optional_source"
      }

      changeset = TimeEntry.changeset(%TimeEntry{}, attrs)

      assert changeset.valid?
      assert changeset.changes.notes == "Optional notes"
      assert changeset.changes.source == "optional_source"
    end
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

    %TaskType{}
    |> TaskType.changeset(attrs)
    |> Dormammu.Repo.insert!()
  end
end
