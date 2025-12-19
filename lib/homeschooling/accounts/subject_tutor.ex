defmodule Homeschooling.Accounts.SubjectTutor do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "subject_tutors" do
    belongs_to :user, Homeschooling.Accounts.User
    belongs_to :subject, Homeschooling.Accounts.Subject
    timestamps()
  end

  @doc false
  def changeset(subject_tutor, attrs) do
    subject_tutor
    |> cast(attrs, [:user_id, :subject_id])
    |> validate_required([:user_id, :subject_id])
    |> unique_constraint([:user_id, :subject_id])
  end
end
