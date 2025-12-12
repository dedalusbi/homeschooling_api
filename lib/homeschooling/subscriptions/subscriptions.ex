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

  # Helper para saber a hierarquia dos planos (1 = Family, 2 = Educator)
  defp plan_weight("family"), do: 1
  defp plan_weight("educator"), do: 2
  defp plan_weight(_), do: 0

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

    #Define se é Upgrade ou Downgrade
    current_weight = plan_weight(Atom.to_string(user.subscription_tier))
    new_weight = plan_weight(new_plan_key)
    is_downgrade = new_weight < current_weight


    if is_nil(new_price_id) do
      {:error, :invalid_plan_configuration}
    else
        IO.puts(">>> Buscando assinatura no Stripe: #{user.stripe_subscription_id}")
        case Stripe.Subscription.retrieve(user.stripe_subscription_id) do
          {:ok, sub} ->
            #Lógica Downgrade Agendado
            if is_downgrade do
              #EDUCATOR -> FAMILY
              handle_downgrade_schedule(sub, new_price_id, new_plan_key)
            else
              #FAMILY->EDUCATOR
              handle_immediate_upgrade(user, sub, new_price_id, new_plan_key)
            end
          {:error, error} ->
            IO.inspect(error, label: ">>> ERRO AO BUSCAR ASSINATURA")
            {:error, error}
        end
    end
  end #def

  #Lógica UPGRADE (imediato - prorrateio - atualização local)
  defp handle_immediate_upgrade(user, sub, new_price_id, new_plan_key) do
    item_id = List.first(sub.itemd.data).id

    params = %{
      items: [%{id: item_id, price: new_price_id}],
      cancel_at_period_end: false,
      proration_behavior: "create_prorations",
      metadata: %{plan_key: new_plan_key, user_id: user.id}
    }

    case Stripe.Subscription.update(sub.id, params) do
      {:ok, updated_sub} ->
        #atualiza o banco na hora (consistência)
        Accounts.update_user_stripe_info(user.id, %{
          subscription_tier: String.to_existing_atom(new_plan_key),
          current_period_end: DateTime.from_unix!(updated_sub.current_period_end),
          cancel_at_period_end: false
        })
        #retorna status para o front saber que foi imediato
        {:ok, %{status: "active", plan: new_plan_key}}
      {:error, error} -> {:error, error}
    end
  end


  #lógica DOWNGRADE (agendado - estilo netflix)
  defp handle_downgrade_schedule(sub, new_price_id, _new_plan_key) do
    current_item = List.first(sub.itemd.data)

    #Verifica se já existe um agendamento, senão cria
    {:ok, schedule} =
      if sub.schedule do
        Stripe.SubscriptionSchedule.retrieve(sub.schedule)
      else
        Stripe.SubscriptionSchedule.create(%{from_subscription: sub.id})
      end
    #Configura as fases: mantém atual até o fim -> troca depois
    params = %{
      phases: [
        %{
          start_date: schedule.current_phase.start_date,
          end_date: sub.current_period_end,
          items: [%{price: current_item.price.id, quantity: 1}]
        },
        %{
          start_date: sub.current_period_end,
          items: [%{price: new_price_id, quantity: 1}],
          proration_behavior: "none"
        }
      ]
    }

    case Stripe.SubscriptionSchedule.update(schedule.id, params) do
      {:ok, _sched} ->
        #não mudar o tier no banco agora. O usuário ainda é premim.
        #Retornamos status 'scheduled' para o frnt avisar
        {:ok, %{status: "scheduled", date: sub.current_period_end}}
      {:error, error} -> {:error, error}
    end
  end
end
