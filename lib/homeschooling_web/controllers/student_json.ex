defmodule HomeschoolingWeb.StudentJSON do
  alias Homeschooling.Accounts.Student

  #Define como renderizar um único aluno
  def student(%{student: student}) do
    %{data: render_student(student)}
  end

  #Define como renderizar uma lista de alunos (para o endpoint GET)
  def index(%{students: students}) do
    %{data: Enum.map(students, &render_student(&1))}
  end

  #Função auxiliar que escolhe os campos a retornar
  defp render_student(%Student{} = student) do
    %{
      id: student.id,
      name: student.name,
      birth_date: student.birth_date,
      grade_level: student.grade_level,
      individualities: student.individualities,
      avatar_id: student.avatar_id,
      inserted_at: student.inserted_at,
      updated_at: student.updated_at
    }
  end

  def index(%{students: students}) do
    #Mapeia cda aluno na lista usando a função auxiliar render_student
    %{data: Enum.map(students, &render_student(&1))}
  end
end
