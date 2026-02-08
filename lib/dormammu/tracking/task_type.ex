defmodule Dormammu.Tracking.TaskType do
  @moduledoc """
  User-defined task categories.
  """
  use Dormammu.Schema

  schema "task_types" do
    field :name, :string
    field :color, :string
    field :position, :integer, default: 0
    field :active, :boolean, default: true
    field :deactivated_at, :utc_datetime_usec

    belongs_to :user, Dormammu.Accounts.User

    timestamps()
  end

  def changeset(task_type, attrs) do
    task_type
    |> cast(attrs, [:name, :color, :position, :active, :user_id, :deactivated_at])
    |> validate_required([:name, :user_id])
    |> unique_constraint(:name, name: :task_types_user_id_name_index)
  end
end
