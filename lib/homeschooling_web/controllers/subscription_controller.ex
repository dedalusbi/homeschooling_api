defmodule HomeschoolingWeb.SubscriptionController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Subscriptions

  #POST /api/subscriptions/checkout
  # Payload esperado: {"plan": "family"} ou {"plan": "educator"}
  def create_checkout_session(conn, %{"plan" => plan_key}) do
    #Obtém o usuário logado
    current_user = conn.assigns.current_user
    #Chama o contexto para criar a sessão no Stripe
    case Subscriptions.create_checkout_session(current_user, plan_key) do
      {:ok, url} ->
        json(conn, %{url: url})

      {:error, :invalid_plan} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Plano inválido. Escolha 'family' ou 'educator'"})

      {:error, _stripe_error} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "Erro ao comunicar com o gateway de pagamento"})
    end
  end

  #Tratamento para payload incoreto
  def create_checkout_session(conn, _params) do
    conn
        |> put_status(:bad_request)
        |> json(%{error: "O parâmetro 'plan' é obrigatório."})
  end

end
