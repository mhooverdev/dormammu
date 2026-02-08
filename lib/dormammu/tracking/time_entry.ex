defmodule Dormammu.Tracking.TimeEntry do
  @moduledoc """
  Time entries per user per task.
  """
  use Dormammu.Schema

  schema "time_entries" do
    field :started_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec
    field :duration_seconds, :integer
    field :notes, :string
    field :source, :string

    belongs_to :user, Dormammu.Accounts.User
    belongs_to :task_type, Dormammu.Tracking.TaskType

    timestamps(updated_at: false)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :started_at,
      :ended_at,
      :duration_seconds,
      :notes,
      :source,
      :user_id,
      :task_type_id
    ])
    |> validate_required([:started_at, :user_id, :task_type_id])
  end
end
