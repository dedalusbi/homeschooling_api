defmodule Homeschooling.Repo.Migrations.AddDateRangeToScheduleEntries do
  use Ecto.Migration

  def change do
    alter table(:schedule_entries) do
      add :start_date, :date, null: false, default: fragment("NOW()")
      add :end_date, :date, null: true
    end
  end
end
