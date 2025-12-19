defmodule Homeschooling.Repo.Migrations.CreateInvitation do
  use Ecto.Migration

  def change do
    create table(:invitations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :email, :string, null: false
      add :token, :string, null: false
      add :role, :string, null: false
      add :status, :string, default: "pending"
      add :expires_at, :utc_datetime
      add :inviter_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :student_id, references(:students, on_delete: :delete_all, type: :uuid), null: false
      add :subject_id, references(:subjects, on_delete: :delete_all, type: :uuid), null: true
      timestamps()
    end
    create unique_index(:invitations, [:token])
    create index(:invitations, [:email, :student_id, :subject_id, :role, :status])
  end
end
