defmodule HomeschoolingWeb.Plugs.RawBodyReader do
  #Lê o corpo da requisição e o armazena em conn.assigns[:raw_body].
  #Isso é necessário para verificar assinaturas de webhooks (como o Stripe)

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    #Guarda o corpo cru nos assigns para uso posterior
    conn = Plug.Conn.assign(conn, :raw_body, body)
    {:ok, body, conn}
  end
end
