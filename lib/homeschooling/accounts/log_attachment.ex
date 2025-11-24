defmodule Homeschooling.Accounts.LogAttachment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  @derive {Jason.Encoder, only: [:id, :file_url, :file_type, :file_name]}

  schema "log_attachments" do
    field :file_url, :string
    field :file_type, :string
    field :file_name, :string

    belongs_to :daily_log, Homeschooling.Accounts.DailyLog

    timestamps(updated_at: false)
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:daily_log_id, :file_url, :file_type, :file_name])
    |> validate_required([:daily_log_id, :file_url])
  end

end
