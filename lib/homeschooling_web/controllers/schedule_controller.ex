defmodule HomeschoolingWeb.ScheduleController do

  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  #Função para lidar com GET /api/students/:student_id/schedules
  def index(conn, %{"student_id" => student_id} = params) do
    current_user = conn.assigns.current_user

    filters = Map.get(params, "filter", %{})

    case Accounts.list_schedule_for_student(current_user, student_id, filters) do
      #Sucesso
      {:ok, schedule_entries} ->
        json(conn, %{data: schedule_entries})

      #Erro: aluno não encontrado ou sem permissão
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Aluno não encontrado."}})


      {:error, :date_range_required} ->
        conn |> put_status(:bad_request) |> json(%{error: "Intervalo de datas é obrigatório."})

      #Outro erro
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado em list_schedule")
        conn |> put_status(:internal_server_error) |> json(%{error: "Erro interno."})
    end
  end

  #Função para lidar com GET /api/schedule/all
  def index_all(conn, params) do
    current_user = conn.assigns.current_user

    filters = Map.get(params, "filter", %{})

    case Accounts.list_all_schedules_for_user(current_user, filters) do
      {:ok, schedule_entries} ->
        json(conn, %{data: schedule_entries})

      {:error, :date_range_required} ->
          conn |> put_status(:bad_request) |> json(%{error: "Intervalo de datas é obrigatório."})
      end


  end



  #Função para lidar com POST /api/schedules
  def create(conn, %{"aula" => aula_params}) do
    current_user = conn.assigns.current_user

    student_id = Map.get(aula_params, "student_id")

    if is_nil(student_id) do
      conn |> put_status(:bad_request) |> json(%{error: "student_id em falta"})
    else

      case Accounts.create_schedule_entries(current_user, student_id, aula_params) do
        #Sucesso
        {:ok, aulas_criadas} ->
          conn
          |> put_status(:created)
          |> json(%{data: aulas_criadas})

        {:error, {:schedule_conflict, conflicts}} ->
          conn
          |> put_status(:conflict)
          |> json(%{
            error: "Conflito de horário detectado",
            details: conflicts
          })


        #Erro: aluno não encontrado ou sem permissão
        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Aluno não encontrado."})

        {:error, %Ecto.Changeset{}=changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})

        #Outro erro
        {:error, reason} ->
          IO.inspect(reason, label: "Erro inesperado em create_schedule_entries")
          conn |> put_status(:internal_server_error) |> json(%{error: "Erro interno."})
      end
    end
  end


  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    case Accounts.get_schedule_entry_for_user(current_user, id) do
      {:ok, entry} -> json(conn, %{data: entry})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Entrada não encontrada."})
    end
  end

  def update(conn, %{"id" => id, "aula"=> aula_params}) do
    current_user = conn.assigns.current_user
    case Accounts.update_schedule_entry_for_user(current_user, id, aula_params) do
      {:ok, entry} -> json(conn, %{data: entry})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Entrada não encontrada."})
      {:error, %Ecto.Changeset{}=changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
        #Outro erro
      {:error, reason} ->
        conn |> put_status(:internal_server_error) |> json(%{error: inspect(reason)})
    end
  end


  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    case Accounts.delete_schedule_entry_for_user(current_user, id) do
      {:ok, _entry} -> send_resp(conn, :no_content, "")
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Entrada não encontrada."})
      {:error, reason} ->
        conn |> put_status(:internal_server_error) |> json(%{error: inspect(reason)})
    end
  end


  def create_exception(conn, %{"id" => id, "aula" => aula_params}) do
    current_user = conn.assigns.current_user

    #O frontend deve enviar "exception_date" dentro de "aula"
    case Accounts.create_schedule_exception(current_user, id, aula_params) do
      {:ok, entry} ->
        conn |> put_status(:created) |> json(%{data: entry})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Aula original não encontrada"})
      {:error, %Ecto.Changeset{} = changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: HomeschoolingWeb.UserController.fomat_errors(changeset)})
    end
  end


  defp format_errors(changeset) do
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
            end)
        end)
  end

end
