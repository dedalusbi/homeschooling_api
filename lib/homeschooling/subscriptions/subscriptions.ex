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
end
