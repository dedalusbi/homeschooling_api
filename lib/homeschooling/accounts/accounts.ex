defmodule Homeschooling.Accounts do
  import Ecto.Query, warn: false
  alias Homeschooling.Repo

  alias Homeschooling.Accounts.User

  def register_user(attrs) do
    with {:ok, changeset} <- {:ok, %User{} |> User.registration_changeset(attrs)},
         {:ok, user} <- Repo.insert(changeset) do
      {:ok, user}
    end
  end
end
