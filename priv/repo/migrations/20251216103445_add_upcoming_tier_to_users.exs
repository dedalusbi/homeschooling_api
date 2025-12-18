defmodule Homeschooling.Repo.Migrations.AddUpcomingTierToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :upcoming_subscription_tier, :string
      add :upcoming_tier_date, :utc_datetime
    end
  end
end
