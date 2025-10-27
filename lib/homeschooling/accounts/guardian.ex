defmodule Homeschooling.Accounts.Guardian do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "guardians" do

    belongs_to :user, Homeschooling.Accounts.User
    belongs_to :student, Homeschooling.Accounts.Student

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(guardian, attrs) do
    guardian
    |> cast(attrs, [:user_id, :student_id])
    |> validate_required([:user_id, :student_id])
    #Adiciona a verificação de unicidade que temos na migração
    |> unique_constraint([:user_id, :student_id], name: :guardians_user_id_student_id_index)
  end
end
