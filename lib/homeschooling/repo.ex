defmodule Homeschooling.Repo do
  use Ecto.Repo,
    otp_app: :homeschooling,
    adapter: Ecto.Adapters.Postgres
end
