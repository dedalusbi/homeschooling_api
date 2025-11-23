defmodule Homeschooling.Repo.Migrations.AddTeachingMaterialsToSubject do
  use Ecto.Migration

  def change do
    alter table(:subjects) do
      add :teaching_materials, :text, null: true
    end
  end
end
