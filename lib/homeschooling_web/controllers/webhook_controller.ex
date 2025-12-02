defmodule HomeschoolingWeb.WebhookController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  #Desliga o CSRF protecion para esta rota (pois vem do Stripe)
  #plug :skip_csrf_protection when action in [:handle]

  def handle(conn, _params) do
    #Ler o corpo (raw) e a assinatura
    body = conn.assigns[:raw_body]
    signature = List.first(get_req_header(conn, "stripe-signature"))
    signing_secret = "whsec_9bed91c997649e891dfb6d2431b78fcd6656e0cf676da46a3022d24334439da0"

    case Stripe.Webhook.construct_event(body, signature, signing_secret) do
      {:ok, %Stripe.Event{type: "checkout.session.completed", data: %{object: session}}} ->
        #Pagamento feito com sucesso
        process_successful_checkout(session)
        send_resp(conn, 200, "OK")
      {:ok, _event} ->
        #Outros eventos
        send_resp(conn, 200, "Ignored")
      {:error, reason} ->
        IO.inspect(reason, label: "Erro Webhook Stripe")
        send_resp(conn, 400, "Webhook Error")
    end
  end

  defp process_successful_checkout(session) do
    IO.inspect(session.metadata, label: ">>> WEBHOOK METADATA")
    #Extrai os metadados que enviamos na criação da sessão
    user_id = session.metadata["user_id"]
    plan_key = session.metadata["plan_key"]
    if user_id && plan_key do
      IO.puts("Atualizando usuário #{user_id} para o plano #{plan_key}")
      result = Accounts.upgrade_subscription(user_id, plan_key)
      IO.inspect(result, label: ">> RESULTADO DO UPGRADE")
    else
      IO.puts(">>> ERRO: Metadata incompleto. USERId: #{inspect(user_id)}, Plan: #{inspect(plan_key)}")
    end
  end
end
