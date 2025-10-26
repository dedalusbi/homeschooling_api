defmodule Homeschooling.Accounts.User do
  use Ecto.Schema
  alias Pbkdf2
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @derive {Jason.Encoder, only: [:id, :email, :full_name, :profile_picture_url, :subscription_tier, :ai_requests_count]}
  @schema_prefix "public"
  schema "users" do
    field :email, :string
    field :full_name, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :profile_picture_url, :string
    field :subscription_tier, Ecto.Enum, values: [:essential, :family, :educator]
    field :ai_requests_count, :integer
    field :payment_gateway_customer_id, :string



    timestamps()
  end


  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name, :email, :password])
    |> validate_required([:full_name, :email, :password])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_length(:password, min: 6)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  # Changeset específico para quando o usuário redefinir a senha
  # através do link de recuperação. Valida apenas o campo de senha.
  def password_reset_changeset(user, attrs) do
    user
    # `cast` que permite apenas que o campo :password seja alterado através deste changeset
    |> cast(attrs, [:password])
    #Valida que a nova senha foi fornecida
    |> validate_required([:password])
    #Valida que a nova senha tem o comprimento mínimo exigido
    |> validate_length(:password, min: 6)
    #Reutiliza a função privada 'put_password_hash para encriptar a nova senha
    |> put_password_hash()
  end


  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end

end
