defmodule Homeschooling.Accounts do
  import Ecto.Query, warn: false
  alias Homeschooling.Repo
  alias Homeschooling.Mailer
  alias Homeschooling.Accounts.User
  alias Homeschooling.Accounts.PasswordResetToken


  def register_user(attrs) do
    with(
      {:ok, changeset} <- {:ok, %User{} |> User.registration_changeset(attrs)},
      {:ok, user} <- Repo.insert(changeset)
    ) do
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

  @doc """
  Gets a single user by ID.
  """
  def get_user_by_id(id) do
    Repo.get(User, id)
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


  #Gera um token de reset de senha, guarda-o (hash) e envia o email
  def generate_and_send_reset_token(email) do
    with( # Encontra o usuário pelo email
         %User{} = user <- Repo.get_by(User, email: email) |> handle_user_not_found(),
         # Gera um token seguro e aleatório
         {:ok, raw_token} <- generate_unique_reset_token(),
         # Define a data de expiração (1 hora a partir de agora)
         expires_at = DateTime.add(DateTime.utc_now(), 3600, :second),
         # Cria o changeset para o token (que inclui o hashing)
         changeset =
           PasswordResetToken.changeset(
             %{user_id: user.id, expires_at: expires_at},
             raw_token
           ),
         # Tenta inserir o token no banco de dados
         {:ok, _reset_token_struct} <- Repo.insert(changeset)
        )do # CORRIGIDO: Insere aqui
      # Se tudo correu bem, envia o email com o token bruto
      send_password_reset_email(user, raw_token)
      {:ok, "Email de recuperação enviado com sucesso."}
    else
      # Se o usuário não foi encontrado (tratado por handle_user_not_found)
      {:error, :user_not_found} ->
        {:error, :user_not_found}

      # Se houve erro ao gerar o token
      {:error, :token_generation_failed} ->
        {:error, :token_generation_failed}

      # Se houve erro ao inserir o token
      # CORRIGIDO: Typo chageset -> changeset
      {:error, changeset} ->
        {:error, {:token_insertion_failed, changeset}}
    end
  end


  # Função auxiliar para o 'with' tratar o 'nil' de Repo.get_by
  defp handle_user_not_found(nil), do: {:error, :user_not_found}
  defp handle_user_not_found(user), do: user

  defp generate_unique_reset_token(retries \\ 5)
  defp generate_unique_reset_token(0), do: {:error, :token_generation_failed}
  defp generate_unique_reset_token(retries) do
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    token_hash = :crypto.hash(:sha256, raw_token) |> Base.encode64(padding: false) |> binary_part(0,43)
    unless Repo.get(PasswordResetToken, token_hash) do
      {:ok, raw_token}
    else
      generate_unique_reset_token(retries-1)
    end
  end


  defp send_password_reset_email(user, raw_token) do
    #Construir a URL do frontend que receberá o token
    reset_url = "http://localhost:8100/auth/reset-password?token=#{raw_token}"
    #Cria o email
    email = Swoosh.Email.new()
    |> Swoosh.Email.to({user.full_name, user.email})
    |> Swoosh.Email.from({"EduCasa App", "dedalusbi@gmail.com"})
    |> Swoosh.Email.subject("Recuperação de senha - App Homeschooling")
    |> Swoosh.Email.html_body("""
      <p>Olá #{user.full_name}, </p>
      <p>Recebemos um pedido para redefinir a sua senha.</p>
      <p>Clique no link abaixo para criar uma nova senha:</p>
      <p><a href="#{reset_url}">Redefinir Senha</a></p>
      <p>Este link expira em 1 hora.</p>
      <p>Se não solicitou esta alteração, favor ignorar este email.</p>
    """)
    Mailer.deliver(email)
  end

  #Redefine a senha do usuário se o token for válido
  def reset_password(token, new_password, confirm_password) do
    # Validações básicas da nova senha
    cond do
      new_password != confirm_password ->
        {:error, :passwords_mismatch}

      String.length(new_password) < 6 ->
        {:error, :password_too_short}

      true ->
        # Calcula o hash do token recebido para procurar na base de dados
        token_hash = :crypto.hash(:sha256, token) |> Base.encode64(padding: false) |> binary_part(0, 43)
        # procura o token na base de dados e pré-carrega o usuário associado
        case Repo.get(PasswordResetToken, token_hash) |> Repo.preload(:user) do
          # Se encontrou o token...
          # CORRIGIDO: Match no token, acessa .user depois
          %Homeschooling.Accounts.PasswordResetToken{expires_at: expires_at} = reset_token ->
            # Verifica se o usuário foi carregado (pode falhar se user_id for inválido)
            case reset_token.user do
              %User{} = user ->
                # Verifica se o token não expirou
                if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
                  # Token válido! Atualiza a senha do usuário
                  result =
                    user
                    |> User.password_reset_changeset(%{password: new_password})
                    |> Repo.update()

                  # Deleta o token APÓS usar o ID dele
                  Repo.delete!(reset_token)

                  case result do
                    {:ok, _user} -> {:ok, "Senha redefinida com sucesso."}
                    {:error, changeset} -> {:error, {:password_update_failed, changeset}}
                  end
                else
                  # Token expirado. Remover
                  Repo.delete!(reset_token)
                  {:error, :token_expired}
                end

              # Caso o preload(:user) falhe (raro, mas possível)
              nil ->
                Repo.delete!(reset_token) # Limpa o token órfão
                {:error, :user_not_found_for_token}
            end

          # Se o token não foi encontrado...
          nil ->
            {:error, :invalid_or_expired_token}
        end
    end
  end


end
