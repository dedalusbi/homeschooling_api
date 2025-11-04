defmodule Homeschooling.Repo.Migrations.AddAvatarIdToStudents do
  use Ecto.Migration

  def change do
    alter table(:students) do
      add :avatar_id, :string, null: true
    end
  end
end
