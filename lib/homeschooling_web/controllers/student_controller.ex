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


end
