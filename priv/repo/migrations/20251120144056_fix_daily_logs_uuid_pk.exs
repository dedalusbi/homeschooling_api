defmodule Homeschooling.Repo.Migrations.FixDailyLogsUuidPk do
  use Ecto.Migration

  def change do

    execute "DROP TABLE daily_logs CASCADE"
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    create table(:daily_logs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :schedule_entry_id, references(:schedule_entries, on_delete: :delete_all, type: :uuid), null: false
      add :log_date, :date, null: false
      add :status, :log_status, null: false
      add :notes, :text

      timestamps(updated_at: false)
    end
    create unique_index(:daily_logs, [:schedule_entry_id, :log_date])
  end
end
