defmodule HomeschoolingWeb.SystemController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  def close_day(conn, params) do
    #Se passar ?date=2025-10-20 usa essa data, senão usa "ontem"
    date = case Map.get(params, "date") do
      nil -> Date.add(Date.utc_today(), -1)
      d -> Date.from_iso8601!(d)
    end
    case Accounts.mark_missed_activities_for_date(date) do
      {:ok, count} ->
        json(conn, %{message: "Dia encerrado. #{count} atividades marcadas como não realizadas.", date: date})
      _ ->
        conn |> put_status(:internal_server_error) |> json(%{error: "Erro ao fechar o dia."})
    end
  end
end
