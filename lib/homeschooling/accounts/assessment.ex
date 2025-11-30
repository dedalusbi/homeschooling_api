defmodule Homeschooling.Accounts.Assessment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  @derive {Jason.Encoder, only: [:id, :subject_id, :title, :assessment_date, :grade, :notes, :inserted_at, :attachments]}

  schema "assessments" do
    field :title, :string
    field :assessment_date, :date
    field :grade, :string
    field :notes, :string

    belongs_to :subject, Homeschooling.Accounts.Subject

    has_many :attachments, Homeschooling.Accounts.AssessmentAttachment

    timestamps()
  end

  def changeset(assessment, attrs) do
    assessment
    |> cast(attrs, [:subject_id, :title, :assessment_date, :grade, :notes])
    |> validate_required([:subject_id, :title, :assessment_date, :grade])
  end

end
