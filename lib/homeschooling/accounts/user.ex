defmodule Homeschooling.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  #CONTINUAR DAQUI ---> Parei no 2. Abra o ficheiro lib/homeschooling/accounts/user.ex e substitua o conteúdo...
  schema "users" do
    field :full_name, :string
    field :email, :string
    field :password_hash, :string
    field :profile_picture_url, :string
    field :payment_gateway_customer_id, :string
    field :ai_requests_count, :integer
    field :subscription_tier, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name, :email, :password_hash, :profile_picture_url, :payment_gateway_customer_id, :ai_requests_count, :subscription_tier])
    |> validate_required([:full_name, :email, :password_hash, :ai_requests_count, :subscription_tier])
  end
end
