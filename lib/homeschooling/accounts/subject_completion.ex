defmodule Homeschooling.Accounts.SubjectCompletion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "subject_completions" do
    field :completion_date, :date
    field :final_report, :string

    belongs_to :subject, Homeschooling.Accounts.Subject
    timestamps(updated_at: false)
  end

  #Changeset para criar um novo relatório de conclusão
  def changeset(completion, attrs) do
    completion
    |> cast(attrs, [:subject_id, :completion_date, :final_report])
    |> validate_required([:subject_id, :completion_date, :final_report])
    |> validate_length(:final_report, min: 100, message: "O relatório final deve ter pelo menos 100 caracteres.")
  end
end
