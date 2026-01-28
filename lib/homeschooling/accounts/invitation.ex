defmodule Homeschooling.Accounts.Invitation do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key{:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "invitations" do
    field :email, :string
    field :token, :string
    field :expires_at, :utc_datetime
    field :role, Ecto.Enum, values: [:guardian, :tutor]
    field :status, Ecto.Enum, values: [:pending, :accepted, :expired], default: :pending
    belongs_to :inviter, Homeschooling.Accounts.User
    belongs_to :student, Homeschooling.Accounts.Student
    belongs_to :subject, Homeschooling.Accounts.Subject
    timestamps()
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :role, :status, :inviter_id, :student_id, :subject_id])
    |> validate_required([:email, :role, :inviter_id, :student_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "deve ser um e-mail válido")
    |> validate_subject_if_tutor()
    |> generate_token_if_missing()
    |> set_expiration()
  end

  #Se for tutor, subject_id é obrigatório
  defp validate_subject_if_tutor(changeset) do
    role = get_field(changeset, :role)
    if role == :tutor do
      validate_required(changeset, [:subject_id])
    else
      changeset
    end
  end
 #ss
  #Gera um token seguro de 32 btes (codificado aqui em Base64 URL-safe)
  defp generate_token_if_missing(changeset) do
    if get_field(changeset, :token) do
      changeset
    else
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      put_change(changeset, :token, token)
    end
  end

  #Define expiração para 7 dias a partir de agora
  defp set_expiration(changeset) do
    if get_field(changeset, :expires_at) do
      changeset
    else
      expiration_date =
        DateTime.utc_now()
        |> DateTime.add(7, :day)
        |> DateTime.truncate(:second)
      put_change(changeset, :expires_at, expiration_date)
    end
  end

end
