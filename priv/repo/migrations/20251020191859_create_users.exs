defmodule Homeschooling.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :full_name, :string
      add :email, :string
      add :password_hash, :string
      add :profile_picture_url, :string
      add :payment_gateway_customer_id, :string
      add :ai_requests_count, :integer
      add :subscription_tier, :string

      timestamps(type: :utc_datetime)
    end
  end
end
