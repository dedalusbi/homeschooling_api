defmodule Homeschooling.Accounts.AssessmentAttachment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @derive {Jason.Encoder, only: [:id, :file_url, :file_type, :file_name]}

  schema "assessment_attachments" do
    field :file_url, :string
    field :file_type, :string
    field :file_name, :string
    belongs_to :assessment, Homeschooling.Accounts.Assessment
    timestamps(updated_at: false)
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:assessment_id, :file_url, :file_type, :file_name])
    |> validate_required([:assessment_id, :file_url])
  end
end
