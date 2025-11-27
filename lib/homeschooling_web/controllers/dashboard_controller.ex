defmodule HomeschoolingWeb.DashboardController do

  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  def stats(conn, _params) do
    current_user = conn.assigns.current_user
    stats = Accounts.get_user_dashboard_stats(current_user)
    json(conn, %{data: stats})
  end



end
