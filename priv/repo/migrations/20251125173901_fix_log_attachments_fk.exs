defmodule Homeschooling.Repo.Migrations.FixLogAttachmentsFk do
  use Ecto.Migration

  def up do
    #apaga a tabela errada
    drop table(:log_attachments)

    #recria corretamente
    create table(:log_attachments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :daily_log_id, references(:daily_logs, on_delete: :delete_all, type: :uuid), null: false
      add :file_url, :string, null: false
      add :file_type, :string
      add :file_name, :string

      timestamps(updated_at: false)
    end

    create index(:log_attachments, [:daily_log_id])

  end

end
