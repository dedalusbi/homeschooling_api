defmodule Homeschooling.Repo.Migrations.AddAvatarIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :profile_picture_url
      add :avatar_id, :string, null: true
    end
  end
end
