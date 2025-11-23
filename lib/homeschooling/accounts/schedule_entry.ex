defmodule Homeschooling.Accounts.ScheduleEntry do

  use Ecto.Schema
  import Ecto.Changeset
  alias Homeschooling.Accounts.{User, Student, Subject, DailyLog}

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  @derive {Jason.Encoder, only: [
    :id, :day_of_week, :start_time, :end_time, :start_date, :end_date, :student_id, :subject_id, :assigned_guardian_id,
    :inserted_at, :updated_at, :specific_date, :excluded_dates, :activities
  ]}
  schema "schedule_entries" do
    field :day_of_week, :integer
    field :start_time, :time
    field :end_time, :time
    field :start_date, :date
    field :end_date, :date
    field :specific_date, :date
    field :excluded_dates, {:array, :date}, default: []
    field :activities, :string

    field :is_recurring, :boolean, virtual: true, default: true

    belongs_to :student, Student, foreign_key: :student_id
    belongs_to :subject, Subject, foreign_key: :subject_id

    has_many :daily_logs, DailyLog
    belongs_to :assigned_guardian, User, foreign_key: :assigned_guardian_id

    timestamps()
  end


  def changeset(schedule_entry, attrs) do
    schedule_entry
    |> cast(attrs, [
      :student_id,
      :subject_id,
      :assigned_guardian_id,
      :start_time,
      :end_time,
      :is_recurring,
      :day_of_week,
      :start_date,
      :end_date,
      :specific_date,
      :excluded_dates,
      :activities

    ])
    |> validate_required([
      :student_id,
      :subject_id,
      :start_time,
      :end_time,
    ])
    |> validate_event_type()
    |> validate_dates()
  end


  defp validate_event_type(changeset) do
    is_recurring = get_field(changeset, :is_recurring)

    if is_recurring do
      changeset
      |> validate_required([:day_of_week, :start_date])
      |> validate_change(:specific_date, fn :specific_date, val ->
        if val, do: [specific_date: "não deve estar preenchido para eventos recorrentes."]
      end)
    else
      changeset
      |> validate_required([:specific_date])
      |> validate_change(:day_of_week, fn :day_of_week, val ->
        if is_nil(val), do: [], else: [day_of_week: "não deve estar preenchido para eventos únicos"]
      end)
      |> validate_change(:start_date, fn :start_date, val ->
        if is_nil(val), do: [], else: [start_date: "não deve estar preenchido para eventos únicos"]
      end)
    end
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
