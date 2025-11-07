defmodule HomeschoolingWeb.SubjectController do
  use HomeschoolingWeb, :controller

  alias Homeschooling.Accounts
  alias Homeschooling.Accounts.Student
  alias Homeschooling.Accounts.Subject



  def index(conn, %{"student_id" => student_id} = params) do
    current_user = conn.assigns.current_user

    #Verifica se o usuário para ver este aluno
    case Accounts.get_student_by_id_for_user(current_user, student_id) do
      %Student{} = student ->
        filters = Map.get(params, "filter", %{})
        subjects = Accounts.list_subjects_for_student(student, filters)
        render(conn, :index, subjects: subjects)

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
        render(conn, :subject, subject: subject)

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
