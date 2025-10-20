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

    #Função privada para formatar os erros do changeset numa forma amigável para o usuário
    defp format_errors(changeset) do
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
            end)
        end)
    end

end