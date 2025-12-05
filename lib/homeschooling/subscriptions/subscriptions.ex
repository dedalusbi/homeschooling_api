defmodule Homeschooling.Subscriptions do
  alias Stripe.Checkout.Session, as: StripeSession
  alias Homeschooling.Accounts.User

  #Mapeamento de planos internos para IDs do Stripe
  #Em produção, pegar de config/runtime.exs
  @plans %{
    "family" => "price_1SZZohJQV5vJKLkqF87Deq2P",
    "educator" => "price_1SZZp3JQV5vJKLkqZUahRNN1"
  }

  #Cria uma sessão de checkout no Stripe para que o usuário faça o upgrade.
  #Retorna a URL para onde o frontend deve redirecionar o usuário.
  def create_checkout_session(%User{}=user, plan_key) do
    price_id = Map.get(@plans, plan_key)
    IO.inspect(price_id, label: "Price ID enviado")

    if is_nil(price_id) do
      {:error, :invalid_plan}
    else
      #Parâmetros para a sessão do Stripe
      params = %{
        mode: "subscription",
        line_items: [
          %{
            price: price_id,
            quantity: 1
          }
        ],
        customer_email: user.email, #pré-preenche o email
        #metadata ajuda a identificar o usuário no webhook depois
        metadata: %{
          user_id: user.id,
          plan_key: plan_key
        },
        success_url: "http://localhost:8100/tabs/profile?session_id={CHECKOUT_SESSION_ID}&status=success",
        cancel_url: "http://localhost:8100/tabs/plan?status=canceled"
      }

      case StripeSession.create(params) do
        {:ok, session} -> {:ok, session.url}
        {:error, stripe_error} -> {:error, stripe_error}
      end

    end
  end


  def change_subscription(%User{}=user, new_plan_key) do

    IO.puts("\n>>> [DEBUG] Iniciando change_subscription para User #{user.id} -> Plano: #{new_plan_key}")


    new_price_id = Map.get(@plans, new_plan_key)
    IO.inspect(new_price_id, label: ">>> Novo Price ID")

    if is_nil(user.stripe_subscription_id) do
      IO.puts(">>> ERRO: Utilizador sem ID de assinatura")
      {:error, :no_active_subscription}
    else
      IO.puts(">>> Buscando assinatura no Stripe: #{user.stripe_subscription_id}")
      case Stripe.Subscription.retrieve(user.stripe_subscription_id) do
        {:ok, sub} ->
          IO.puts(">>> Assinatura encontrada no Stripe")
          item_id = List.first(sub.items.data).id
          IO.inspect(item_id, label: ">>> ID do Item da Assinatura (subscription_item)")
          #Atualiza a assinatura
          #O stipe calcula a pro-rata automaticamente para upgrades.
          #para downgrades, ele dá crédito
          params = %{
            items: [%{id: item_id, price: new_price_id}],
            proration_behavior: "create_prorations",
            metadata: %{
              plan_key: new_plan_key,
              user_id: user.id
            }
          }
          IO.inspect(params, label: ">>> Params enviados para Stripe.Subscription.update")

          case Stripe.Subscription.update(user.stripe_subscription_id, params) do
            {:ok, updated_sub} ->
              IO.puts(">>> SUCESSO: Stripe respondeu com OK")
              # Opcional: Retornar a sub atualizada para inspeção
              {:ok, updated_sub}
           {:error, error} ->
              IO.inspect(error, label: ">>> ERRO NO UPDATE DO STRIPE")
              {:error, error}
          end

        {:error, error} ->
          IO.inspect(error, label: ">>> ERRO AO BUSCAR ASSINATURA")
          {:error, error}
      end
    end #if

  end #def

end
