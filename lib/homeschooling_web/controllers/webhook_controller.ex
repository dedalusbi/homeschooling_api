defmodule HomeschoolingWeb.WebhookController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  #Desliga o CSRF protecion para esta rota (pois vem do Stripe)
  #plug :skip_csrf_protection when action in [:handle]

  def handle(conn, _params) do

    IO.puts("\n>>> DEBUG Webhook Atingido!")

    try do

      body = conn.assigns[:raw_body]

      if is_nil(body) do
        IO.puts(">>> [ERRO CRÍTICO] raw_body é NIL! Verifique o endpoint.ex")
        raise "Raw Body Missing"
      end

      IO.puts(">>> DEBUG Corpo recebido (tamanho): #{byte_size(body)} bytes")

      signature = List.first(get_req_header(conn, "stripe-signature"))
      signing_secret = "whsec_9bed91c997649e891dfb6d2431b78fcd6656e0cf676da46a3022d24334439da0"

      case Stripe.Webhook.construct_event(body, signature, signing_secret) do
        {:ok, %Stripe.Event{type: "checkout.session.completed", data: %{object: session}}} ->
          IO.puts(">>> [DEBUG] Evento de Checkout Recebido")
          #Pagamento feito com sucesso
          process_successful_checkout(session)
          send_resp(conn, 200, "OK")

        {:ok, %Stripe.Event{type: "customer.subscription.updated", data: %{object: subscription}}} ->
          IO.puts(">>> [DEBUG] Evento de Atualização Recebido")
          #Pagamento feito com sucesso
          process_subscription_update(subscription)
          send_resp(conn, 200, "OK")

        {:ok, event} ->
          #Outros eventos
          IO.puts(">>> [DEBUG] Evento Ignorado: #{event.type}")
          send_resp(conn, 200, "Ignored")
        {:error, reason} ->
          IO.inspect(reason, label: "Erro Webhook Stripe")
          send_resp(conn, 400, "Webhook Error")
      end
    rescue
      e ->
        IO.inspect(e, label: ">>> [EXCEPTION] Crash no Webhook")
        IO.inspect(__STACKTRACE__, label: "Stacktrace")
        send_resp(conn, 500, "Internal Server Error")

    end

  end

  defp process_successful_checkout(session) do
    IO.inspect(session, label: ">>> SESSÃO COMPLETA") # Para vermos o que vem

    user_id = session.metadata["user_id"]
    plan_key = session.metadata["plan_key"]

    # Extrai os IDs corretos
    stripe_sub_id = session.subscription # Deve ser "sub_..."
    stripe_cus_id = session.customer         # Deve ser "cus_..."

    if user_id && plan_key do
      IO.puts("Atualizando usuário #{user_id} para o plano #{plan_key}")

      current_period_end =
        case Stripe.Subscription.retrieve(stripe_sub_id) do
          {:ok, sub} ->
            DateTime.from_unix!(sub.current_period_end)
          _ ->
            IO.puts(">>> AVISO: Não foi possível buscar data de assinatura no checkout.")
            DateTime.add(DateTime.utc_now(), 30, :day)
        end


      # Atualiza TUDO de uma vez
      result = Accounts.update_user_stripe_info(user_id, %{
        stripe_subscription_id: stripe_sub_id,
        payment_gateway_customer_id: stripe_cus_id, # Atualiza também o customer_id para garantir
        subscription_tier: String.to_existing_atom(plan_key), # Força a atualização do plano AQUI também
        current_period_end: current_period_end,
        cancel_at_period_end: false
      })

      IO.inspect(result, label: ">> RESULTADO DO UPGRADE")
    else
      IO.puts(">>> ERRO: Metadata incompleto...")
    end
  end

  #Atualizar assinatura
  defp process_subscription_update(subscription) do
    IO.puts("\n======== INÍCIO PROCESSAMENTO WEBHOOK ATUALIZAÇÃO ==============")
    customer_id = subscription.customer
    IO.inspect(customer_id, label: "1. Customer ID do Stripe")
    user = Accounts.get_user_by_stripe_id(customer_id)
    IO.inspect(user, label: "2. Utilizador Encontrado?")

    if user do
      plan_key = get_plan_key_from_price(subscription.items.data)
      IO.inspect(plan_key, label: "3. Chave do plano identificada")

      current_period_end = case subscription.current_period_end do
        nil -> nil
        ts when is_integer(ts) -> DateTime.from_unix!(ts)
        _ -> nil
      end
      IO.inspect(current_period_end, label: "4. Data do Período")

      attrs = %{
        subscription_tier: plan_key,
        current_period_end: current_period_end,
        cancel_at_period_end: subscription.cancel_at_period_end,
        stripe_subscription_id: subscription.id
      }

      result = Accounts.update_user_stripe_info(user.id, attrs)
      IO.inspect(result, label: "5. Resultado do update no banco")
    end
    IO.puts("================= FIM PROCESSAMENTO WEBHOOK ================= \n")
  rescue
    e ->
      IO.puts("!!! EXCEÇÃO NO WEBHOOK !!!")
      IO.inspect(e, label: "Erro")
      IO.inspect(__STACKTRACE__, label: "Stacktrace")
      reraise e, __STACKTRACE__
  end

  #Helper para descobrir qual o plano baseado no Price ID que veio do stripe
  defp get_plan_key_from_price(items_data) do

    case List.first(items_data) do
      nil ->
        IO.puts("AVISO: Lista de items vazia no webhook")
        :essential

      item ->
        price_id =
          cond do
            is_map(item.price) -> item.price.id
            true ->
              IO.inspect(item, label: "Item do Stripe com formato inesperado")
              nil
          end

        IO.inspect(price_id, label: "Price ID recebido do Stripe")

        case price_id do
          "price_1SZZohJQV5vJKLkqF87Deq2P" -> :family
          "price_1SZZp3JQV5vJKLkqZUahRNN1" -> :educator
          _ ->
            IO.puts("AVISO: Price ID desconhecido: #{inspect(price_id)}")
            :essential
        end
    end
  end



end
