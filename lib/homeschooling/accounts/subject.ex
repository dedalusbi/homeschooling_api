defmodule Homeschooling.Accounts.Subject do

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @derive {Jason.Encoder, only: [:id, :student_id, :name, :description, :status, :inserted_at, :completion]}

  schema "subjects" do
    field :name, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:active, :completed], default: :active

    belongs_to :student, Homeschooling.Accounts.Student, type: Ecto.UUID

    has_one :completion, Homeschooling.Accounts.SubjectCompletion

    timestamps()
  end

  def changeset(subject, attrs) do
    subject
    |> cast(attrs, [:student_id, :name, :description, :status])
    |> validate_required([:student_id, :name, :status])
    |> validate_inclusion(:status, [:active, :completed])
  end

end
