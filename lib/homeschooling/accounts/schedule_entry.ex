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
    field :start_date, :date
    field :end_date, :date

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
      :end_time,
      :start_date,
      :end_date
    ])
    |> validate_required([
      :student_id,
      :subject_id,
      :day_of_week,
      :start_time,
      :end_time,
      :start_date
    ])
    |> validate_dates()
  end


  defp validate_dates(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)
    if (start_date && end_date && Date.compare(end_date, start_date) == :lt) do
      add_error(changeset, :end_date, "A data de término deve ser após a data de início.")
    else
      changeset
    end
  end

end
