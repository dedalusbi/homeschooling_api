defmodule Homeschooling.Accounts.PasswordResetToken do
  use Ecto.Schema
  import Ecto.Changeset
  alias Homeschooling.Repo
  alias Homeschooling.Accounts.User

  @primary_key {:token_hash, :string, autogenerate: false}
  @foreign_key_type Ecto.UUID
  schema "password_reset_tokens" do
    #Guardamos o hash do token para comparação segura
    field :expires_at, :utc_datetime
    timestamps(updated_at: false)

    belongs_to :user, User, foreign_key: :user_id, type: Ecto.UUID
  end

  #Changeset para criar um novo token (gerando hash)
  def changeset(attrs, raw_token, token_struct \\ %__MODULE__{}) do
    token_struct
    |> cast(attrs, [:user_id, :expires_at])
    |> validate_required([:user_id, :expires_at])
    #Gera o hash do token bruto antes de guardar
    |> put_token_hash(raw_token)
    |> unsafe_validate_unique([:token_hash], Repo, message: "token hash collision")
  end

  #função auxiliar para gerar o hash do token
  defp put_token_hash(changeset, raw_token) do
    #Usamos a função de hash segura do elixir
    token_hash = :crypto.hash(:sha256, raw_token)
      |> Base.encode64(padding: false)
      |> binary_part(0,43)
    put_change(changeset, :token_hash, token_hash)
  end
end
