defmodule Homeschooling.Repo.Migrations.AddSpecificDateToScheduleEntries do
  use Ecto.Migration

  def change do
    alter table(:schedule_entries) do
      add :specific_date, :date, null: true
      modify :day_of_week, :integer, null: true
      modify :start_date, :date, null: true
    end
  end
end
