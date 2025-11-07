defmodule HomeschoolingWeb.ScheduleController do

  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  #Função para lidar com GET /api/students/:student_id/schedules
  def index(conn, %{"student_id" => student_id}) do
    current_user = conn.assigns.current_user

    case Accounts.list_schedule_for_student(current_user, student_id) do
      #Sucesso
      {:ok, schedule_entries} ->
        json(conn, %{data: schedule_entries})

      #Erro: aluno não encontrado ou sem permissão
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Aluno não encontrado."}})

      #Outro erro
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado em list_schedule")
        conn |> put_status(:internal_server_error) |> json(%{error: "Erro interno."})
    end
  end

end
