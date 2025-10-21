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

  def login_user(email, password) do
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        #Verifica se a senha fornecida corresponde ao hash guardado
        if Pbkdf2.verify_pass(password, user.password_hash) do
          generate_jwt(user)
        else
          {:error, :invalid_credentials}
        end

      nil ->
        {:error, :invalid_credentials}
    end
  end


  #Função privada auxiliar para gerar o token JWT
  defp generate_jwt(user) do
    claims = %{
      "sub" => user.id,
      "exp" => DateTime.utc_now() |> DateTime.add(60*60*24*7) |> DateTime.to_unix()
    }

    key = Application.fetch_env!(:homeschooling, :jwt_secret)

    signer = Joken.Signer.create("HS256", key)

    Joken.encode_and_sign(claims, signer)
  end


end
