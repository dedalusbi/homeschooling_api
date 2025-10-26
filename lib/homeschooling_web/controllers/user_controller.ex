defmodule HomeschoolingWeb.UserController do

    use HomeschoolingWeb, :controller
    alias Homeschooling.Accounts
    alias Homeschooling.Accounts.User


    def register(conn, %{"user" => user_params}) do
        case Accounts.register_user(user_params) do
            {:ok, :verification_email_sent ,_user} ->
                conn
                |> put_status(:created)
                |> json(%{message: "Conta criada. Verifique seu email para ativar."})

            {:error, %Ecto.Changeset{}=changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{errors: format_errors(changeset)})

            {:error, reason} ->
                conn
                |> put_status(:internal_server_error)
                |> json(%{error: "Ocorreu um erro inesperado durante o registro."})
        end
    end

    #Função para lidar com a requisição POST /api/users/login
    # Recebe a conexão `conn` e os parâmetros `user_params` (email e senha)
    def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
        #Chama a função de negócio do contexto `Accounts`
        case Accounts.login_user(email, password) do

            #Se o login for bem-sucedido retornar um token...
            {:ok, token, _claims} ->
                #Envia uma resposta JSON com status 200 (OK) e o token JWT
                conn
                |> put_status(:ok)
                |> json(%{token: token})

            #Se o login falhar (email não encontrado ou senha incorreta)...
            {:error, :invalid_credentials} ->
                #Envia uma resposta JSON com status 401 (Não autorizado)
                conn
                |> put_status(:unauthorized)
                |> json(%{error: %{status: 401, message: "Credenciais inválidas"}})


            {:error, :email_not_verified} ->
                conn
                |> put_status(:forbidden)
                |> json(%{error: %{status: 403, message: "Email não verificado. Verifique sua caixa de entrada."}})
        end
    end


    #Essa função só será alcançada se o AuthPlug for bem-sucedido
    #O Plug já colocou os dados do utilizador na `conn` para nós
    def me(conn, _params) do
        current_user = conn.assigns.current_user
        json(conn, %{data: current_user})
    end



    #Função privada para formatar os erros do changeset numa forma amigável para o usuário
    defp format_errors(changeset) do
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
            end)
        end)
    end


    #Endpoint para solicitar a recuperação de senha
    #Recebe: {"email": "user@example.com"}
    def request_password_reset(conn, %{"email" => email}) do
        case Accounts.generate_and_send_reset_token(email) do
            #Sucesso ou email não encontrado - retornamos sempre OK para não vazar informação
            {:ok, message} ->
                json(conn, %{message: message})
            {:error, :user_not_found} ->
                #logar com o erro internamente, se necessário
                json(conn, %{message: "Se o email estiver registrado, receberá instruções."})
            {:error, reason} ->
                #Logar com o erro internamente
                conn
                |> put_status(:internal_server_error)
                |> json(%{error: "Ocorreu um erro inesperado."})
        end
    end
    def request_password_reset(conn, _params) do
        conn |> put_status(:bad_request) |> json(%{error: "Email em falta."})
    end


    #Endpoint para efetivar a redefinição de senha
    #Recebe {"token": "...", "password": "...", "confirm_password": "..."}
    def reset_password(conn, %{"token" => token, "password" => password, "confirm_password" => confirm}) do
        case Accounts.reset_password(token, password, confirm) do
            {:ok, message} ->
                json(conn, %{message: message})
            {:error, :passwords_mismatch} ->
                conn |> put_status(:unprocessable_entity) |> json(%{error: "As senhas não coincidem."})
            {:error, :password_too_short} ->
                conn |> put_status(:unprocessable_entity) |> json(%{error: "A senha deve ter pelo menos 6 caracteres."})
            {:error, :invalis_or_expired_token} ->
                conn |> put_status(:unprocessable_entity) |> json(%{error: "Token inválido ou expirado."})
            {:error, {:password_update_failed, changeset}} ->
                conn |> put_status(:unprocessable_entity) |> json(%{error: "Erro ao atualizar a senha.", details: format_errors(changeset)})
            {:error, reason} ->
                #Logar erro interno
                conn |> put_status(:internal_server_error) |> json(%{error: "Ocorreu um erro inesperado."})

        end
    end
    def reset_password(conn, _params) do
        conn |> put_status(:bad_request) |> json(%{error: "Dados em falta"})
    end

end
