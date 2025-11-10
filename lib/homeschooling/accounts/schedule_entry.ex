defmodule Homeschooling.Accounts.ScheduleEntry do

  use Ecto.Schema
  import Ecto.Changeset
  alias Homeschooling.Accounts.{User, Student, Subject}

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  @derive {Jason.Encoder, only: [
    :id, :day_of_week, :start_time, :end_time, :student_id, :subject_id, :assigned_guardian_id, :inserted_at, :updated_at
  ]}
  schema "schedule_entries" do
    field :day_of_week, :integer
    field :start_time, :time
    field :end_time, :time

    belongs_to :student, Student, foreign_key: :student_id
    belongs_to :subject, Subject, foreign_key: :subject_id

    belongs_to :assigned_guardian, User, foreign_key: :assigned_guardian_id

    timestamps()
  end


  def changeset(schedule_entry, attrs) do
    schedule_entry
    |> cast(attrs, [
      :student_id,
      :subject_id,
      :assigned_guardian_id,
      :day_of_week,
      :start_time,
      :end_time
    ])
    |> validate_required([
      :student_id,
      :subject_id,
      :day_of_week,
      :start_time,
      :end_time
    ])
  end

end
