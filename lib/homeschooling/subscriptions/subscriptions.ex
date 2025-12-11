defmodule Homeschooling.Subscriptions do
  alias Stripe.Checkout.Session, as: StripeSession
  alias Homeschooling.Accounts.User
  alias Homeschooling.Accounts
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


  #Downgrade para o plano 'essential'
  def change_subscription(%User{}=user, "essential") do
    IO.puts("\n>>> [DEBUG] Processamento downgrade para Essential (cancelamento)")

    if is_nil(user.stripe_subscription_id) do
      {:ok, user} #Usuário já não tem assinatura paga
    else
      #Atualiza no stripe para cancelar no fim do período
      params = %{cancel_at_period_end: true}

      case Stripe.Subscription.update(user.stripe_subscription_id, params) do
        {:ok, updated_sub} ->
          IO.puts(">>> SUCESSO: Assinatura agendada para cancelamento no Stripe")
          #Atualiza imediatamente o status no banco local para refletir a interface
          current_period_end = DateTime.from_unix!(updated_sub.current_period_end)
          Accounts.update_user_stripe_info(user.id, %{
            cancel_at_period_end: true,
            current_period_end: current_period_end
          })
          {:ok, updated_sub}

        {:error, error} ->
          IO.inspect(error, label: ">>> ERRO AO CANCELAR ASSINATURA")
          {:error, error}
      end
    end
  end

  #Troca entre planos pagos (Family <--> Educator)
  def change_subscription(%User{}=user, new_plan_key) do

    IO.puts("\n>>> [DEBUG] Iniciando change_subscription para User #{user.id} -> Plano: #{new_plan_key}")


    new_price_id = Map.get(@plans, new_plan_key)
    IO.inspect(new_price_id, label: ">>> Novo Price ID")

    if is_nil(new_price_id) do
      {:error, :invalid_plan_configuration}
    else
      if is_nil(user.stripe_subscription_id) do
        IO.puts(">>> ERRO: Usuário sem ID de assinatura para fazer upgrade/downgrade")
        {:error, :no_active_subscription}
      else
        IO.puts(">>> Buscando assinatura no Stripe: #{user.stripe_subscription_id}")
        case Stripe.Subscription.retrieve(user.stripe_subscription_id) do
          {:ok, sub} ->
            IO.puts(">>> Assinatura encontrada no Stripe")
            #pega o id do item atual para substituí-lo
            item_id = List.first(sub.items.data).id
            IO.inspect(item_id, label: ">>> ID do item da assinatura.")
            params = %{
              items: [%{id: item_id, price: new_price_id}],
              #Garante que a assinatura não será cancelada se o usuário estiver reativando
              cancel_at_period_end: false,
              proration_behavior: "create_prorations",
              metadata: %{
                plan_key: new_plan_key,
                user_id: user.id
              }
            }
            IO.inspect(params, label: ">>> Params enviados para Stripe.Subscription.update ")

            case Stripe.Subscription.update(user.stripe_subscription_id, params) do
              {:ok, updated_sub} ->
                IO.puts(">>> SUCESSO: Stripe respondeu com OK")
                #Se o usuário tinha um cancelamento agendado e fez upgrade,
                #atualizamos o banco local para remover a flag de cancelamento.
                current_period_end = DateTime.from_unix!(updated_sub.current_period_end)
                if user.cancel_at_period_end do
                  Accounts.update_user_stripe_info(user.id, %{
                    cancel_at_period_end: false,
                    current_period_end: current_period_end
                  })
                end
                {:ok, updated_sub}
              {:error, error} ->
                IO.inspect(error, label: ">>> ERRO NO UPDATE DO STRIPE")
                {:error, error}
            end
          {:error, error} ->
            IO.inspect(error, label: ">>> ERRO AO BUSCAR ASSINATURA")
            {:error, error}
        end
      end
    end
  end #def

end
