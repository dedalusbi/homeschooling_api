defmodule Homeschooling.Repo.Migrations.CreateUserDevices do
  use Ecto.Migration

  def change do
    create table(:user_devices, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      add :fcm_token, :text, null: false
      add :device_info, :map
      timestamps()
    end
    create index(:user_devices, [:user_id])
    create unique_index(:user_devices, [:fcm_token])
  end
end
