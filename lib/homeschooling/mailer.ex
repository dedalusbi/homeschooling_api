defmodule Homeschooling.Mailer do
  use Swoosh.Mailer, otp_app: :homeschooling
  import Swoosh.Email

  # Função para disparar o convite
  def send_invitation(invitation) do
    # Define a URL do frontend (hardcoded por enquanto, depois por em config)
    accept_url = "http://localhost:8100/invites/accept?token=#{invitation.token}"

    new()
    |> to(invitation.email)
    |> from({"EduCasa System", "no-reply@educasa.app"})
    |> subject("Você foi convidad(o) para colaborar no EduCasa!")
    |> html_body("""
      <h1>Olá!</h1>
      <p>Você foi convidado para participar como <strong>#{invitation.role}</strong>.</p>
      <p>Clique no link abaixo para aceitar:</p>
      <a href="#{accept_url}">Aceitar Convite</a>
      <p>Este link expira em 7 dias.</p>
    """)
    |> text_body("""
      Olá!
      Você foi convidado para participar como #{invitation.role}.
      Acesse o link para aceitar: #{accept_url}
    """)
    |> deliver()
  end
end
