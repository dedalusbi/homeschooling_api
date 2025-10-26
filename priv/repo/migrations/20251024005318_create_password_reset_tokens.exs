defmodule Homeschooling.Repo.Migrations.CreatePasswordResetTokens do
  use Ecto.Migration

  def change do
    create table(:password_reset_tokens, primary_key: false) do
      #Usaremos o próprio token como chave primária para facilitar a busca
      add :token_hash, :string, primary_key: true
      #Referência ao utilizador ao qual o token pertence
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      #Data e hora em que o token expira
      add :expires_at, :utc_datetime, null: false
      #Data de criação do token
      timestamps(updated_at: false)
    end
    #índice no user_id para otimizar a busca de tokens de um usuário
    create index(:password_reset_tokens, [:user_id])
  end
end
