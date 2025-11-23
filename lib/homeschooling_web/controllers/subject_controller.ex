defmodule HomeschoolingWeb.SubjectController do
  use HomeschoolingWeb, :controller

  alias Homeschooling.Accounts
  alias Homeschooling.Accounts.Student
  alias Homeschooling.Accounts.Subject
  alias Homeschooling.Accounts.DailyLog



  def index(conn, %{"student_id" => student_id} = params) do
    current_user = conn.assigns.current_user

    #Verifica se o usuário para ver este aluno
    case Accounts.get_student_by_id_for_user(current_user, student_id) do
      %Student{} = student ->
        filters = Map.get(params, "filter", %{})
        subjects = Accounts.list_subjects_for_student(student, filters)

        #Calcula estatísticas para cada matéria
        subjects_with_stats = Enum.map(subjects, fn subject ->
          stats = Accounts.get_subject_stats(subject)
          #Adiciona os campos virtuais
          Map.merge(subject, stats)
        end)

        render(conn, :index, subjects: subjects_with_stats)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Aluno não encontrado."}})
    end
  end


  def create(conn, %{"student_id" => student_id, "subject" => subject_params}) do
    current_user = conn.assigns.current_user

    case Accounts.create_subject_for_student(current_user, student_id, subject_params) do

      {:ok, subject} ->
        conn
        |> put_status(:created)
        |> render("subject.json", subject: subject)

      #Erro: aluno não encontrado ou sem permissão
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Aluno não encontrado."}})

      #Erro: dados da matéria inválidos
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: HomeschoolingWeb.UserController.format_errors(changeset)})

      #Outro erro
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado no create_subject")
        conn |> put_status(:internal_server_error) |> json(%{error: %{status: 500, message: "Erro interno."}})

    end
  end


  def show(conn, %{"id" => subject_id}) do
    current_user = conn.assigns.current_user

    case Accounts.get_subject_by_id_for_user(current_user, subject_id) do
      %Subject{}=subject ->
        #Estatísticas
        stats = Accounts.get_subject_stats(subject)

        #histórico (logs concluídos)
        history = Accounts.get_daily_log_history_for_subject(subject.id)

        subject_with_data =
          subject
          |> Map.merge(stats)
          |> Map.put(:history, history)
        render(conn, :subject, subject: subject_with_data)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Matéria não encontrada"}})
    end
  end



  def update(conn, %{"id" => subject_id, "subject" => subject_params}) do
    current_user = conn.assigns.current_user

    case Accounts.update_subject_for_user(current_user, subject_id, subject_params) do
      {:ok, subject} ->
        render(conn, :subject, subject: subject)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Matéria não encontrada."}})

      #Erro: dados da matéria inválidos
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: HomeschoolingWeb.UserController.format_errors(changeset)})

      #Outro erro
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado no update_subject")
        conn |> put_status(:internal_server_error) |> json(%{error: %{status: 500, message: "Erro interno."}})
    end
  end


   def complete(conn, %{"id" => subject_id, "report" => report_params}) do
    current_user = conn.assigns.current_user

    case Accounts.complete_subject_for_user(current_user, subject_id, report_params) do
      {:ok, subject} ->
        render(conn, :subject, subject: subject)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Matéria não encontrada."})

      {:error, :already_completed} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Esta matéria já está concluída."})

      #Erro: dados da matéria inválidos
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: HomeschoolingWeb.UserController.format_errors(changeset)})

      #Outro erro
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado no complete_subject")
        conn |> put_status(:internal_server_error) |> json(%{error: "Erro interno."})
    end
  end


  def reactivate(conn, %{"id" => subject_id}) do
    current_user = conn.assigns.current_user

    case Accounts.reactivate_subject_for_user(current_user, subject_id) do
      {:ok, subject} ->
        render(conn, :subject, subject: subject)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Matéria não encontrada."})

      {:error, :already_active} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Esta matéria já está ativa."})

      #Outro erro
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado no reactivate_subject")
        conn |> put_status(:internal_server_error) |> json(%{error: "Erro interno."})
    end
  end

  def delete(conn, %{"id" => subject_id}) do
    current_user = conn.assigns.current_user

    case Accounts.delete_subject_for_user(current_user, subject_id) do
      {:ok, _subject_struct} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Matéria não encontrada."}})

      #Outro erro
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado no delete_subject")
        conn |> put_status(:internal_server_error) |> json(%{error: "Erro interno."})
    end
  end


end
