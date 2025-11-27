defmodule Homeschooling.Accounts.Student do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @derive {Jason.Encoder, only: [:id, :name, :birth_date, :grade_level, :individualities, :avatar_id, :inserted_at, :updated_at, :guardians]}
  schema "students" do
    field :name, :string
    field :birth_date, :date
    field :grade_level, :string
    field :individualities, {:array, :map}
    field :avatar_id, :string

    has_many :guardians, Homeschooling.Accounts.Guardian

    timestamps(type: :utc_datetime)
  end

  @doc false
  #Change set para criar/atualizar um aluno
  def changeset(student_struct, attrs) do

    student_struct
    |> cast(attrs, [:name, :birth_date, :grade_level, :individualities])
    |> validate_required([:name])
    |> cast(attrs, [:avatar_id])
  end


end
