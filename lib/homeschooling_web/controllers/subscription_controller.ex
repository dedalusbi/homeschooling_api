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


  def change_plan(conn, %{"plan" => plan_key}) do
    # Obtém o utilizador logado
    current_user = conn.assigns.current_user

    # Chama a função de contexto que atualiza diretamente no Stripe
    case Subscriptions.change_subscription(current_user, plan_key) do
      {:ok, _subscription} ->
        # Sucesso! O Webhook depois tratará de atualizar o banco local,
        # mas podemos retornar sucesso imediato.
        json(conn, %{message: "Plano alterado com sucesso!"})

      {:error, :no_active_subscription} ->
        # Proteção: Se o frontend chamar isto para um user grátis por engano
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Utilizador não possui assinatura ativa. Use o checkout."})

      {:error, :invalid_plan} ->
         conn
         |> put_status(:bad_request)
         |> json(%{error: "Plano inválido."})

      {:error, stripe_error} ->
        # Erro do Stripe (ex: cartão recusado na tentativa de pro-rata)
        IO.inspect(stripe_error, label: "Erro Stripe Change Plan")
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "Erro ao alterar o plano. Verifique o método de pagamento."})
    end
  end
end
