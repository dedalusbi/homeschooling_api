defmodule HomeschoolingWeb.VerificationController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  #Função para lidar com a requisição de verificação (via GET ou POST)
  #Se usar GET, o token vem como parâmetro de URL (:token)
  #Se usar POST, esperamos {"token": "..."} no corpo
  def verify(conn, %{"token" => token}) do
    handle_verification(conn, token)
  end

  #Para GET com parâmetro de rota /:token (precisa de ajuste no router)
  #def verify(conn, %{"token" => token_from_path}) do
  #  handle_verification(conn, token_from_path)
  #end

  defp handle_verification(conn, token) do
    case Accounts.verify_user_email(token) do
      {:ok, _user} ->
      json(conn, %{message: "Email verificado com sucesso."})
      {:error, :invalid_token} ->
        conn |> put_status(:not_found) |> json(%{error: "Link de verificação inválido"})
      {:error, :token_expired} ->
        conn |> put_status(:gone) |> json(%{error: "Link de verificação expirado."})
    end

  end


  #Endpoint para solicitar o reenvio do email de verificação.
  #Recebe: {"email": "user@example.com"}
  def resend(conn, %{"email" => email}) do
    case Accounts.resend_verification_email(email) do
      {:ok, message} ->
        json(conn, %{message: message})

      {:error, :internal_server_error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Ocorreu um erro ao processar a solicitação"})

    end
  end
  def resend(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "Email em falta."})
  end

end
