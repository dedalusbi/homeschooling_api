defmodule HomeschoolingWeb.DailyLogController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts


  def create(conn, %{"id" => schedule_entry_id, "log" => log_params}) do
    current_user = conn.assigns.current_user

    case Accounts.create_or_update_daily_log(current_user, schedule_entry_id, log_params) do
      {:ok, log} ->
        conn |> put_status(:ok) |> json(%{data: log})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Aula não encontrada."})
      {error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Erro interno"})
    end
  end


end
