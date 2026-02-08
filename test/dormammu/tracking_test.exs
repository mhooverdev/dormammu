defmodule Dormammu.TrackingTest do
  use Dormammu.DataCase

  alias Dormammu.Tracking
  alias Dormammu.Tracking.{TaskType, TimeEntry}
  alias Dormammu.Accounts.User

  describe "task_types" do
    alias Dormammu.Tracking.TaskType

    @valid_attrs %{name: "Development"}
    @update_attrs %{name: "Updated Development", active: false}
    @invalid_attrs %{name: nil}

    test "list_task_types/2 returns all active task types for user" do
      user = insert_user()
      task1 = insert_task_type(user, %{name: "Task 1", active: true})
      task2 = insert_task_type(user, %{name: "Task 2", active: true})
      _task3 = insert_task_type(user, %{name: "Task 3", active: false})
      other_user = insert_user(%{os_username: "other"})
      _other_task = insert_task_type(other_user, %{name: "Other Task"})

      tasks = Tracking.list_task_types(user)
      assert length(tasks) == 2
      assert task1 in tasks
      assert task2 in tasks
    end

    test "list_task_types/2 with include_inactive option includes inactive tasks" do
      user = insert_user()
      _task1 = insert_task_type(user, %{name: "Task 1", active: true})
      task2 = insert_task_type(user, %{name: "Task 2", active: false})

      tasks = Tracking.list_task_types(user, include_inactive: true)
      assert length(tasks) >= 2
      assert task2 in tasks
    end

    test "get_task_type/2 returns task for user" do
      user = insert_user()
      task = insert_task_type(user, @valid_attrs)
      assert Tracking.get_task_type(user, task.id).id == task.id
    end

    test "get_task_type/2 returns nil for other user's task" do
      user = insert_user()
      other_user = insert_user(%{os_username: "other"})
      task = insert_task_type(other_user, @valid_attrs)
      assert Tracking.get_task_type(user, task.id) == nil
    end

    test "create_task_type/2 with valid data creates a task type" do
      user = insert_user()
      assert {:ok, %TaskType{} = task} = Tracking.create_task_type(user, @valid_attrs)
      assert task.name == "Development"
      assert task.user_id == user.id
    end

    test "create_task_type/2 with invalid data returns error changeset" do
      user = insert_user()
      assert {:error, %Ecto.Changeset{}} = Tracking.create_task_type(user, @invalid_attrs)
    end

    test "update_task_type/2 with valid data updates the task type" do
      user = insert_user()
      task = insert_task_type(user, @valid_attrs)
      assert {:ok, %TaskType{} = task} = Tracking.update_task_type(task, @update_attrs)
      assert task.name == "Updated Development"
      assert task.active == false
    end

    test "update_task_type/2 with invalid data returns error changeset" do
      user = insert_user()
      task = insert_task_type(user, @valid_attrs)
      assert {:error, %Ecto.Changeset{}} = Tracking.update_task_type(task, @invalid_attrs)
      assert task == Tracking.get_task_type(user, task.id)
    end

    test "deactivate_task_type/1 deactivates the task type" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Task", active: true})
      assert {:ok, updated} = Tracking.deactivate_task_type(task)
      assert updated.active == false
    end
  end

  describe "time_entries" do
    alias Dormammu.Tracking.TimeEntry

    test "current_entry/1 returns active entry for user" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Task"})
      entry = insert_time_entry(user, task, %{ended_at: nil})

      assert Tracking.current_entry(user).id == entry.id
    end

    test "current_entry/1 returns nil when no active entry" do
      user = insert_user()
      assert Tracking.current_entry(user) == nil
    end

    test "list_entries/2 returns all entries for user" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Task"})
      entry1 = insert_time_entry(user, task, %{started_at: ~U[2024-01-01 10:00:00Z]})
      entry2 = insert_time_entry(user, task, %{started_at: ~U[2024-01-02 10:00:00Z]})
      other_user = insert_user(%{os_username: "other"})
      other_task = insert_task_type(other_user, %{name: "Other Task"})
      _other_entry = insert_time_entry(other_user, other_task)

      entries = Tracking.list_entries(user)
      assert length(entries) >= 2
      # Should be ordered by started_at desc
      assert hd(entries).id == entry2.id
    end

    test "list_entries/2 with since option filters by date" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Task"})
      old_entry = insert_time_entry(user, task, %{started_at: ~U[2024-01-01 10:00:00Z]})
      new_entry = insert_time_entry(user, task, %{started_at: ~U[2024-01-15 10:00:00Z]})

      entries = Tracking.list_entries(user, since: ~U[2024-01-10 00:00:00Z])
      assert new_entry.id in Enum.map(entries, & &1.id)
      refute old_entry.id in Enum.map(entries, & &1.id)
    end

    test "list_entries_all/1 returns all entries" do
      user1 = insert_user()
      user2 = insert_user(%{os_username: "user2"})
      task1 = insert_task_type(user1, %{name: "Task 1"})
      task2 = insert_task_type(user2, %{name: "Task 2"})
      entry1 = insert_time_entry(user1, task1)
      entry2 = insert_time_entry(user2, task2)

      entries = Tracking.list_entries_all()
      assert entry1.id in Enum.map(entries, & &1.id)
      assert entry2.id in Enum.map(entries, & &1.id)
    end

    test "list_entries_all/1 with limit option limits results" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Task"})
      _entry1 = insert_time_entry(user, task, %{started_at: ~U[2024-01-01 10:00:00Z]})
      _entry2 = insert_time_entry(user, task, %{started_at: ~U[2024-01-02 10:00:00Z]})
      _entry3 = insert_time_entry(user, task, %{started_at: ~U[2024-01-03 10:00:00Z]})

      entries = Tracking.list_entries_all(limit: 2)
      assert length(entries) == 2
    end

    test "stop_active_entry/1 stops active entry and calculates duration" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Task"})
      started_at = DateTime.add(DateTime.utc_now(), -3600, :second)
      entry = insert_time_entry(user, task, %{started_at: started_at, ended_at: nil})

      assert {:ok, updated} = Tracking.stop_active_entry(user)
      assert updated.id == entry.id
      assert updated.ended_at
      assert updated.duration_seconds >= 3600
    end

    test "stop_active_entry/1 returns ok when no active entry" do
      user = insert_user()
      assert {:ok, nil} = Tracking.stop_active_entry(user)
    end

    test "start_entry/2 creates new entry and stops existing one" do
      user = insert_user()
      task1 = insert_task_type(user, %{name: "Task 1"})
      task2 = insert_task_type(user, %{name: "Task 2"})
      old_entry = insert_time_entry(user, task1, %{ended_at: nil})

      assert {:ok, new_entry} = Tracking.start_entry(user, task2)
      assert new_entry.task_type_id == task2.id
      assert new_entry.ended_at == nil

      # Old entry should be stopped
      updated_old = Dormammu.Repo.get!(TimeEntry, old_entry.id)
      assert updated_old.ended_at
    end

    test "land_on_task/2 creates entry for task" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Task"})

      assert {:ok, entry} = Tracking.land_on_task(user, task)
      assert entry.task_type_id == task.id
      assert entry.user_id == user.id
      assert entry.started_at
    end

    test "update_entry/2 updates entry" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Task"})
      entry = insert_time_entry(user, task)

      assert {:ok, updated} = Tracking.update_entry(entry, %{notes: "Updated notes"})
      assert updated.notes == "Updated notes"
    end

    test "export_entries_csv/2 generates CSV" do
      user = insert_user()
      task = insert_task_type(user, %{name: "Development"})
      started = ~U[2024-01-01 10:00:00Z]
      ended = ~U[2024-01-01 11:00:00Z]

      insert_time_entry(user, task, %{
        started_at: started,
        ended_at: ended,
        duration_seconds: 3600,
        notes: "Test notes"
      })

      csv = Tracking.export_entries_csv(user)
      assert csv =~ "task,start,end,duration_seconds,notes"
      assert csv =~ "Development"
      assert csv =~ "Test notes"
      assert csv =~ "3600"
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

    %TimeEntry{}
    |> TimeEntry.changeset(attrs)
    |> Dormammu.Repo.insert!()
  end
end
