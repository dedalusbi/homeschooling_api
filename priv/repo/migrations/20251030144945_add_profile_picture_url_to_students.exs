defmodule Homeschooling.Repo.Migrations.AddProfilePictureUrlToStudents do
  use Ecto.Migration

  def change do
    alter table(:students) do
      # Adiciona a nova coluna para guardar o URL da imagem
      add :profile_picture_url, :string, null: true
    end
  end
end
