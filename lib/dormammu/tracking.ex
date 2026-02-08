defmodule Dormammu.Tracking do
  @moduledoc """
  Time tracking context: tasks and time entries.
  """
  import Ecto.Query, warn: false
  alias Dormammu.Repo
  alias Dormammu.Tracking.{TaskType, TimeEntry}
  alias Dormammu.Accounts.User

  # -- Tasks
  def list_task_types(%User{id: user_id}, opts \\ []) do
    base =
      TaskType
      |> where([t], t.user_id == ^user_id)
      |> order_by([t], asc: t.position, asc: t.inserted_at)

    base =
      if Keyword.get(opts, :include_inactive, false) do
        base
      else
        where(base, [t], t.active == true)
      end

    base =
      if Keyword.get(opts, :include_deactivated, false) do
        base
      else
        where(base, [t], is_nil(t.deactivated_at))
      end

    Repo.all(base)
  end

  def get_task_type(%User{id: user_id}, id) do
    TaskType |> where([t], t.user_id == ^user_id and t.id == ^id) |> Repo.one()
  end

  def create_task_type(%User{id: user_id}, attrs) do
    %TaskType{}
    |> TaskType.changeset(Map.put(attrs, :user_id, user_id))
    |> Repo.insert()
  end

  def update_task_type(%TaskType{} = task_type, attrs) do
    task_type |> TaskType.changeset(attrs) |> Repo.update()
  end

  def update_task_positions(%User{id: user_id}, ordered_task_ids)
      when is_list(ordered_task_ids) do
    updates =
      ordered_task_ids
      |> Enum.with_index()
      |> Enum.map(fn {id, pos} -> %{id: id, position: pos} end)

    Repo.transaction(fn ->
      for %{id: id, position: pos} <- updates do
        TaskType
        |> where([t], t.id == ^id and t.user_id == ^user_id)
        |> Repo.update_all(set: [position: pos])
      end
    end)
  end

  def deactivate_task_type(%TaskType{} = task_type) do
    update_task_type(task_type, %{active: false})
  end

  def soft_delete_task_type(%TaskType{} = task_type) do
    update_task_type(task_type, %{deactivated_at: DateTime.utc_now()})
  end

  # -- Time entries
  def current_entry(%User{id: user_id}) do
    TimeEntry
    |> where([e], e.user_id == ^user_id and is_nil(e.ended_at))
    |> Repo.one()
    |> Repo.preload(:task_type)
  end

  def list_entries(%User{id: user_id}, opts \\ []) do
    base =
      TimeEntry
      |> where([e], e.user_id == ^user_id)
      |> order_by([e], desc: e.started_at)
      |> preload(:task_type)

    base =
      case Keyword.get(opts, :since) do
        nil -> base
        %DateTime{} = dt -> where(base, [e], e.started_at >= ^dt)
      end

    Repo.all(base)
  end

  def list_entries_all(opts \\ []) do
    base =
      TimeEntry
      |> order_by([e], desc: e.started_at)
      |> preload([:task_type, :user])

    base =
      case Keyword.get(opts, :date_from) do
        nil ->
          base

        %Date{} = d ->
          dt = DateTime.new!(d, ~T[00:00:00], "Etc/UTC")
          where(base, [e], e.started_at >= ^dt)
      end

    base =
      case Keyword.get(opts, :date_to) do
        nil ->
          base

        %Date{} = d ->
          dt = DateTime.new!(d, ~T[23:59:59], "Etc/UTC")
          where(base, [e], e.started_at <= ^dt)
      end

    base =
      case Keyword.get(opts, :limit) do
        nil -> base
        :all -> base
        n when is_integer(n) -> limit(base, ^n)
      end

    Repo.all(base)
  end

  def export_entries_all_csv(opts \\ []) do
    entries = list_entries_all(opts)

    headers = ["user", "task", "start", "end", "duration_seconds", "notes"]

    rows =
      for e <- entries do
        [
          user_name(e.user),
          (e.task_type && e.task_type.name) || "",
          format_dt(e.started_at),
          format_dt(e.ended_at),
          e.duration_seconds || "",
          e.notes || ""
        ]
      end

    ([headers] ++ rows)
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp user_name(nil), do: "Unknown"
  defp user_name(u), do: u.display_name || u.os_username || u.email || "User"

  def stop_active_entry(%User{} = user) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      case current_entry(user) do
        nil ->
          {:ok, nil}

        entry ->
          duration =
            case entry.started_at do
              nil -> nil
              started_at -> DateTime.diff(now, started_at, :second)
            end

          {:ok, updated} =
            entry
            |> TimeEntry.changeset(%{ended_at: now, duration_seconds: duration})
            |> Repo.update()

          {:ok, updated}
      end
    end)
    |> unwrap_tx_result()
  end

  def start_entry(%User{id: user_id} = user, %TaskType{id: task_id}) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      _ = stop_active_entry(user)

      %TimeEntry{}
      |> TimeEntry.changeset(%{
        user_id: user_id,
        task_type_id: task_id,
        started_at: now,
        source: "widget"
      })
      |> Repo.insert()
    end)
    |> unwrap_tx_result()
  end

  def land_on_task(%User{} = user, %TaskType{} = task_type) do
    start_entry(user, task_type)
  end

  def update_entry(%TimeEntry{} = entry, attrs) do
    entry |> TimeEntry.changeset(attrs) |> Repo.update()
  end

  def export_entries_csv(%User{} = user, opts \\ []) do
    entries = list_entries(user, opts)

    headers = ["task", "start", "end", "duration_seconds", "notes"]

    rows =
      for e <- entries do
        [
          (e.task_type && e.task_type.name) || "",
          format_dt(e.started_at),
          format_dt(e.ended_at),
          e.duration_seconds || "",
          e.notes || ""
        ]
      end

    ([headers] ++ rows)
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  defp format_dt(nil), do: ""

  defp format_dt(%DateTime{} = dt) do
    DateTime.to_iso8601(dt)
  end

  defp unwrap_tx_result({:ok, {:ok, value}}), do: {:ok, value}
  defp unwrap_tx_result({:ok, other}), do: other
  defp unwrap_tx_result(other), do: other
end
