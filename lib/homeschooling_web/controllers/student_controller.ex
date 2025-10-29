defmodule HomeschoolingWeb.StudentController do

  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts
  alias Homeschooling.Accounts.Student


  #action_fallback HomeschoolingWeb.FallbackController


  def create(conn, %{"student" => student_params}) do

    #O AuthPlug já colocou o utilizador em conn.assigns.current_user
    current_user = conn.assigns.current_user

    case Accounts.create_student(current_user, student_params) do
      {:ok, student} ->
        conn
        |> put_status(:created)
        |> render("student.json", student: student)
      {:error, :student_limit_reached} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: %{status: 403, message: "Limite de alunos atingido."}})
      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "!!! Changeset inválido recebido no controller")
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado em create_student")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{status: 500, message: "Erro interno ao criar aluno."}})

    end

  end



  defp format_errors(changeset) do
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
            end)
        end)
    end


  # Função para lidar com GET /api/students
  def index(conn, _params) do
    current_user = conn.assigns.current_user

    #Chama a função de negócio para buscar os alunos
    students = Accounts.list_students_for_user(current_user)

    render(conn, :index, students: students)

  end


  #Função para lidar com GET /api/students/:id
  def show(conn, %{"id" => student_id}) do
    current_user = conn.assigns.current_user

    #chama a função de negócio segura para buscar o aluno
    case Accounts.get_student_by_id_for_user(current_user, student_id) do
      %Student{} = student ->
        render(conn, :student, student: student)

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Aluno não encontrado."}})
    end
  end


  #Função para lidar com PUT /api/students/:id
  def update(conn, %{"id" => student_id, "student" => student_params}) do
    current_user = conn.assigns.current_user
    #Chama a função de negócio para atualizar o aluno
    case Accounts.update_student_for_user(current_user, student_id, student_params) do
      {:ok, student} ->
        render(conn, :student, student: student)
      #Aluno não encontrado ou não pertence ao usuário
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Aluno não encontrado."}})
      #dados inválidos (changeset com error)
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: HomeschoolingWeb.UserController.format_errors(changeset)})
      #outro erro inesperado
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado em update_student")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{status: 500, message: "Erro interno ao atualizar o aluno."}})
    end
  end


  #Função para lidar com DELETE /api/students/:id
  def delete(conn, %{"id" => student_id}) do
    current_user = conn.assigns.current_user

    #Chama a função de negócio para atualizar o aluno
    case Accounts.delete_student_for_user(current_user, student_id) do
      {:ok, _student} ->
        send_resp(conn, :no_content, "")
      #Aluno não encontrado ou não pertence ao usuário
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{status: 404, message: "Aluno não encontrado."}})
      #outro erro inesperado
      {:error, reason} ->
        IO.inspect(reason, label: "Erro inesperado em update_student")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{status: 500, message: "Erro interno ao remover o aluno."}})
    end
  end

end
