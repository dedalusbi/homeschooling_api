defmodule Homeschooling.Repo.Migrations.CreateSubjectTutors do
  use Ecto.Migration

  def change do
    create table(:subject_tutors, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :subject_id, references(:subjects, on_delete: :delete_all, type: :uuid), null: false
      timestamps()
    end
    create index(:subject_tutors, [:user_id])
    create index(:subject_tutors, [:subject_id])
    #Garante que um usuário não seja tutor da mesma matéria duas vezes
    create unique_index(:subject_tutors, [:user_id, :subject_id])
  end
end
