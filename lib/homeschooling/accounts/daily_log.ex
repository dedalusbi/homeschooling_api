defmodule Homeschooling.Accounts.DailyLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @derive {Jason.Encoder, only: [:id, :schedule_entry_id, :log_date, :status, :notes, :inserted_at]}

  schema "daily_logs" do
    field :log_date, :date
    field :status, Ecto.Enum, values: [:completed, :missed]
    field :notes, :string

    belongs_to  :schedule_entry, Homeschooling.Accounts.ScheduleEntry, type: Ecto.UUID, foreign_key: :schedule_entry_id

    timestamps(updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:schedule_entry_id, :log_date, :status, :notes])
    |> validate_required([:schedule_entry_id, :log_date, :status])
  end

end
