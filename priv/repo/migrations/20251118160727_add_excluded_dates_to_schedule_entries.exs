defmodule Homeschooling.Repo.Migrations.AddExcludedDatesToScheduleEntries do
  use Ecto.Migration

  def change do
    alter table(:schedule_entries) do
      add :excluded_dates, {:array, :date}, default: []
    end
  end
end
