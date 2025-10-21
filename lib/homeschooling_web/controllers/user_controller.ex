defmodule HomeschoolingWeb.UserController do

    use HomeschoolingWeb, :controller
    alias Homeschooling.Accounts
    alias Homeschooling.Accounts.User


    def register(conn, %{"user" => user_params}) do
        case Accounts.register_user(user_params) do
            {:ok, _user} ->
                conn
                |> put_status(:created)
                |> json(%{message: "Usuário registrado com sucesso"})

            {:error, changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{errors: format_errors(changeset)})
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

        end
    end




    #Função privada para formatar os erros do changeset numa forma amigável para o usuário
    defp format_errors(changeset) do
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
            end)
        end)
    end

end
