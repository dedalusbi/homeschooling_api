defmodule Homeschooling.Repo.Migrations.CreateAssessmentAttachments do
  use Ecto.Migration

  def change do
    create table(:assessment_attachments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :assessment_id, references(:assessments, on_delete: :delete_all, type: :uuid), null: false
      add :file_url, :string, null: false
      add :file_type, :string
      add :file_name, :string
      timestamps(updated_at: false)
    end
    create index(:assessment_attachments, [:assessment_id])
  end
end
