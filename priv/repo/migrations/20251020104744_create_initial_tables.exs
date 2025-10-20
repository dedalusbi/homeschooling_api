defmodule Homeschooling.Repo.Migrations.CreateInitialTables do
  use Ecto.Migration

  def change do
    # --- Tipos Personalizados (ENUMs)
    execute("CREATE TYPE subscription_tier AS ENUM ('essential', 'family', 'educator')")
    execute("CREATE TYPE subject_status AS ENUM ('active', 'completed')")
    execute("CREATE TYPE log_status AS ENUM ('completed', 'missed')")
    execute("CREATE TYPE device_type AS ENUM ('ios', 'android')")


    # --- Tabela de Usuários ---
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :subscription_tier, :subscription_tier, null: false, default: "essential"
      add :ai_requests_count, :integer, null: false, default: 0
      add :payment_gateway_customer_id, :string

      timestamps()
    end
    create unique_index(:users, [:email])
    create unique_index(:users, [:payment_gateway_customer_id])





    # --- Tabela de Estudantes ---
    create table(:students, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :birth_date, :date
      add :grade_level, :string
      add :individualities, :map

      timestamps()
    end


    # ---Tabela Guardians (junção entre user e students)
    create table(:guardians) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :student_id, references(:students, on_delete: :delete_all, type: :uuid), null: false
    end
    create unique_index(:guardians, [:user_id, :student_id])


    # --- Tabela Subjects
    create table(:subjects, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :student_id, references(:students, on_delete: :delete_all, type: :uuid), null: false
      add :name, :string, null: false
      add :description, :text
      add :status, :subject_status, null: false, default: "active"

      timestamps()
    end

    # --- Tabela Schedule Entries
    create table(:schedule_entries, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :student_id, references(:students, on_delete: :delete_all, type: :uuid), null: false
      add :subject_id, references(:subjects, on_delete: :delete_all, type: :uuid), null: false
      add :assigned_guardian_id, references(:users, on_delete: :nilify_all, type: :uuid)
      add :day_of_week, :integer, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false

      timestamps()
    end

    create table(:daily_logs) do
      add :schedule_entry_id, references(:schedule_entries, on_delete: :delete_all, type: :uuid), null: false
      add :log_date, :date, null: false
      add :status, :log_status, null: false
      add :notes, :text

      timestamps(updated_at: false)
    end
    create unique_index(:daily_logs, [:schedule_entry_id, :log_date])

    # --- Tabela Log Attachments ---
    create table(:log_attachments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :daily_log_id, references(:daily_logs, on_delete: :delete_all), null: false
      add :file_url, :string, null: false
      add :file_type, :string
      add :file_name, :string

      timestamps(updated_at: false)
    end


    # --- Tabela Assessments ---
    create table(:assessments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :subject_id, references(:subjects, on_delete: :delete_all, type: :uuid), null: false
      add :title, :string, null: false
      add :assessment_date, :date, null: false
      add :grade, :string
      add :notes, :text

      timestamps()
    end

    # --- Tabela subject_completions
    create table(:subject_completions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :subject_id, references(:subjects, on_delete: :delete_all, type: :uuid), null: false
      add :completion_date, :date, null: false
      add :final_report, :text

      timestamps(updated_at: false)
    end
    create unique_index(:subject_completions, [:subject_id])


    # --- Tabela completion_attachments
    create table(:completion_attachments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :subject_completion_id, references(:subject_completions, on_delete: :delete_all, type: :uuid), null: false
      add :file_url, :string, null: false
      add :file_type, :string
      add :file_name, :string

      timestamps(updated_at: false)
    end

    # --- Tabela templates
    create table(:templates, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :name, :string, null: false
      add :description, :text
      add :recommended_grade_level, :string
      add :is_public, :boolean, null: false, default: false

      timestamps()
    end

    # --- Tabela template_items
    create table(:template_items, primary_key: false) do
      add :template_id, references(:templates, on_delete: :delete_all, type: :uuid), null: false
      add :subject_name, :string, null: false
      add :day_of_week, :integer, null: false
      add :start_time, :time, null: false
      add :end_time, :time, null: false
    end

    # --- Tabela template_tags
    create table(:template_tags) do
      add :template_id, references(:templates, on_delete: :delete_all, type: :uuid), null: false
      add :tag, :string, null: false
    end
    create unique_index(:template_tags, [:template_id, :tag])

    # ---Tabela template ratings
    create table(:template_ratings) do
      add :template_id, references(:templates, on_delete: :delete_all, type: :uuid), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :rating, :integer, null: false
      add :comment, :text
    end
    create unique_index(:template_ratings, [:template_id, :user_id])


    # --Tabela device_tokens
    create table(:device_tokens) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :token, :string, null: false
      add :device_type, :device_type, null: false
    end
    create unique_index(:device_tokens, [:token])


  end
end
