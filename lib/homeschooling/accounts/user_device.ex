defmodule Homeschooling.Accounts.UserDevice do
  use Ecto.Schema
  import Ecto.Changeset
  alias Homeschooling.Accounts.User


  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "user_devices" do
    field :fcm_token, :string
    field :device_info, :map #ex: {"model": "iPhone 13", "os": "iOS 17"}
    belongs_to :user, User
    timestamps()
  end

  def changeset(device, attrs) do
    device
    |> cast(attrs, [:user_id, :fcm_token, :device_info])
    |> validate_required([:user_id, :fcm_token])
    #Garante que não salvamos tokens duplicados na força bruta
    |> unique_constraint(:fcm_token)
  end

end
