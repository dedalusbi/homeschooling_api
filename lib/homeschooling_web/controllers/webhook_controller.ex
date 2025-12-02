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

      {:ok, %Stripe.Event{type: "customer.subscription.updated", data: %{object: subscription}}} ->
        #Pagamento feito com sucesso
        process_subscription_update(subscription)
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
    sub_id = session.subscription
    if user_id  do
      Accounts.update_user_stripe_info(user_id, %{stripe_subscription_id: sub_id})
    end
  end

  #Atualizar assinatura
  defp process_subscription_update(subscription) do
    #Busca o usuário pelo stripe_subscription_id
    #OU usa o metadata se o Stripe o preservar
    customer_id = subscription.customer
    user = Accounts.get_user_by_stripe_id(customer_id)
    if user do
      plan_key = get_plan_key_from_price(subscription.items.data)
      attrs = %{
        subscription_tier: plan_key,
        current_period_end: DateTime.from_unix!(subscription.current_period_end),
        cancel_at_period_end: subscription.cancel_at_period_end
      }

      Accounts.update_user_stripe_info(user.id, attrs)
    end
  end

  #Helper para descobrir qual o plano baseado no Price ID que veio do stripe
  defp get_plan_key_from_price([item | _]) do
    price_id = item.price.id
    case price_id do
      "price_1SZZohJQV5vJKLkqF87Deq2P" -> :family
      "price_1SZZp3JQV5vJKLkqZUahRNN1" -> :educator
      _ -> :essential
    end
  end
end
