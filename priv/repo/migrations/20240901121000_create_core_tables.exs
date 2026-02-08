defmodule Dormammu.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :os_username, :string, null: false
      add :display_name, :string
      add :role, :string, null: false, default: "user"
      add :email, :string
      add :password_hash, :string
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:users, [:os_username])
    create unique_index(:users, [:email])

    create table(:task_types, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :color, :string
      add :position, :integer, default: 0
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create index(:task_types, [:user_id])
    create unique_index(:task_types, [:user_id, :name])

    create table(:time_entries, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :task_type_id, references(:task_types, type: :uuid, on_delete: :nilify_all), null: false
      add :started_at, :utc_datetime_usec, null: false
      add :ended_at, :utc_datetime_usec
      add :duration_seconds, :integer
      add :notes, :text
      add :source, :string

      timestamps(updated_at: false)
    end

    create index(:time_entries, [:user_id])
    create index(:time_entries, [:task_type_id])
    create index(:time_entries, [:started_at])
    create index(:time_entries, [:user_id, :ended_at])
  end
end
