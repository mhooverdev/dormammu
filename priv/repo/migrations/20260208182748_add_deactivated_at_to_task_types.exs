defmodule Dormammu.Repo.Migrations.AddDeactivatedAtToTaskTypes do
  use Ecto.Migration

  def change do
    alter table(:task_types) do
      add :deactivated_at, :utc_datetime_usec
    end

    create index(:task_types, [:deactivated_at])
  end
end
