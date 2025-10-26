defmodule Homeschooling.Repo.Migrations.AddEmailVerificationToUsers do
  use Ecto.Migration

  def change do
    # --- Adiciona a coluna `verified_at` à tabela `users` ---
    alter table(:users) do
      # TIMESTAMPTZ guarda data e hora com fuso horário
      # null: true utilizadores existentes não verificados
      add :verified_at, :timestamptz, null: true
    end

    # --- Cria a tabela `email_verification_tokens` ---
    # Estrutura muito similar à de password_reset_tokens
    create table(:email_verification_tokens, primary_key: false) do
      # Usaremos o hash do token como chave primária
      add :token_hash, :string, primary_key: true, size: 43 #Tamanho para Base64 SHA256
      #Referência ao usuário a quem o token pertence
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      #Data e hora em que o token expira
      add :expires_at, :utc_datetime, null: false
      #Data de criação do token
      timestamps(updated_at: false)
    end
    #Índice no user_id para otimizar a busca (ex.: reenviar token)
    create index(:email_verification_tokens, [:user_id])

  end
end
