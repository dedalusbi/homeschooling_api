defmodule HomeschoolingWeb.DeviceController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  action_fallback HomeschoolingWeb.FallbackController

  def create(conn, device_params) do
    user = conn.assigns.current_user
    with {:ok, _device} <- Accounts.register_device(user, device_params) do
      conn
      |> put_status(:created)
      |> json(%{success: true, message: "Dispositivo registrado para notificações."})
    end
  end
end
