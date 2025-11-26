defmodule Homeschooling.Repo.Migrations.AddRecurrenceGroupId do
  use Ecto.Migration

  def change do
    alter table(:schedule_entries) do
      #Um Id comum partilhado por todas as aulas da mesma série recorente
      add :recurrence_group_id, :uuid, null: true
    end

    #ìndice para buscar rapidamente todas as aulas de um grupo
    create index(:schedule_entries, [:recurrence_group_id])
  end
end
