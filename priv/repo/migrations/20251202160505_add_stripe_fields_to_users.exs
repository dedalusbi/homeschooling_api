defmodule Homeschooling.Repo.Migrations.AddStripeFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :stripe_subscription_id, :string
      add :current_period_end, :utc_datetime
      add :cancel_at_period_end, :boolean, default: false
    end
  end
end
