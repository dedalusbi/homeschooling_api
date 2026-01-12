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
      |> json(%{success: true, message: "Convite enviado para #{_invitation.email}",
      token: _invitation.token #retornar isso só em DEV para testar sem email!
      })
    end
  end

  #POST /api/invitations/accept
  def accept(conn, %{"token" => token}) do
    user = conn.assigns.current_user

    case Accounts.accept_invitation(user, token) do
      {:ok, result} ->
        conn |> json(%{success: true, message: result.message, role: result.role})
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: reason})
    end
  end

  #GET /api/invitations/check/:token (para o front validar antes de aceitar)
  def show(conn, %{"token" => token}) do
    case Accounts.get_invitation_by_token(token) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Convite inválido"})
      invitation ->
        json(conn, %{
          valid: true,
          inviter: invitation.inviter.full_name,
          student: invitation.student.name,
          role: invitation.role
        })
    end
  end


end
