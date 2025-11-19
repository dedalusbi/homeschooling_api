defmodule Homeschooling.Repo.Migrations.AddActivitiesToScheduleEntries do
  use Ecto.Migration

  def change do
    alter table(:schedule_entries) do
      add :activities, :text, null: true
    end
  end
end
