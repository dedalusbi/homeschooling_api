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


  #GET /api/logs?date=YYYY-MM-DD
  def index(conn, %{"date" => date_str}) do
    user = conn.assigns.current_user
    date = Date.from_iso8601!(date_str)
    logs = Accounts.list_daily_logs_for_date(user, date)
    json(conn, %{data: logs})
  end

  #Helper para pegar URL de upload (Frontend chama este primeiro)
  #GET /api/logs/upload_url?filename=...&type=...
  def upload_url(conn, %{"filename" => filename, "type" => type}) do
    {:ok, data} = Accounts.generate_attachment_presigned_url(filename, type)
    json(conn, %{data: data})
  end

  #POST /api/logs/:id/attachments
  #O frontend envia a URL pública do S3 aqui para salvar no banco
  def create_attachment(conn, %{"id" => log_id, "attachment" => attachment_params}) do
    case Accounts.create_log_attachment(log_id, attachment_params) do
      {:ok, attachment} ->
        conn |> put_status(:created) |> json(%{data: attachment})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: changeset})
    end
  end

end
