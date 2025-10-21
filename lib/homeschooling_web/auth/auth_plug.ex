defmodule HomeschoolingWeb.Auth.AuthPlug do

  import Plug.Conn
  alias Homeschooling.Accounts
  alias Jason

  def init(opts), do: opts

  def call(conn, _opts) do
    IO.inspect(conn.req_headers, label: "Cabeçalhos recebidos")
    with(
    {:ok, token} <- get_token(conn),
    _ <- IO.inspect(token, label: "Token recebido"),
    {:ok, claims} <- verify_token(token),
    _ <- IO.inspect(claims, label: "Claims Verificados"),
    {:ok, user} <- get_user(claims)
    ) do
      assign(conn, :current_user, user)
    else
      error ->
        IO.inspect(error, label: "ERRO no WITH")
        send_unauthorized(conn)
    end
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      [header] ->
        case header do
          "Bearer " <> token ->
            {:ok, token}
          "bearer " <> token ->
            {:ok, token}
          _ ->
            {:error, :invalid_header_format}
        end
      [] -> {:error, :no_token}
    end
  end


  defp verify_token(token) do

    key = Application.fetch_env!(:homeschooling, :jwt_secret)
    signer = Joken.Signer.create("HS256", key)
    Joken.verify(token, signer)

  end

  #Carrega o utilizador da base de dados usando o ID do token
  defp get_user(%{"sub" => user_id}) do
    case Accounts.get_user_by_id(user_id) do
      user -> {:ok, user}
      nil -> {:error, :user_not_found}
    end
  end
  #Se o token não tiver o campo "sub", é inválido
  defp get_user(_), do: {:error, :invalid_token_claims}

  #Envia uma reposta de erro 401 e para a requisição
  defp send_unauthorized(conn) do
    body = Jason.encode!(%{error: %{status: 401, message: "Unauthorized"}})

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(401, body)
    |> halt()
  end




end
