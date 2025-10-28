defmodule Homeschooling.Accounts.Student do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @derive {Jason.Encoder, only: [:id, :name, :birth_date, :grade_level, :individualities, :inserted_at, :updated_at]}
  schema "students" do
    field :name, :string
    field :birth_date, :date
    field :grade_level, :string
    field :individualities, {:array, :map}

    #Relação M-to-M com Users através de Guardians
    #many_to_many :users, Homeschooling.Accounts.User, join_through: "guardians"

    timestamps(type: :utc_datetime)
  end

  @doc false
  #Change set para criar/atualizar um aluno
  def changeset(student, attrs) do
    student
    |> cast(attrs, [:name, :birth_date, :grade_level, :individualities])
    |> validate_required([:name])
  end
end
