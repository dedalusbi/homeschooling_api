defmodule HomeschoolingWeb.InvitationController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  action_fallback HomeschoolingWeb.FallbackController

  #POST /api/invitations
  def create(conn, invitation_params) do
    inviter = conn.assigns.current_user
    with {:ok, _invitation} <- Accounts.create_invitation(inviter, invitation_params) do
      conn
      |> put_status(:created)
      |> json(%{success: true, message: "Convite enviado para #{invitation.email}",
      token: invitation.token #retornar isso só em DEV para testar sem email!
      })
    end
  end

  #POST /api/invitations/accept
  def accept(conn, %{"token" => token}) do

  end
end
