defmodule HomeschoolingWeb.StudentJSON do
  alias Homeschooling.Accounts.Student

  #Define como renderizar um único aluno
  def student(%{student: student}) do
    %{data: render_student(student)}
  end

  #Define como renderizar uma lista de alunos (para o endpoint GET)
  def index(%{students_data: students_data}) do
    %{data: Enum.map(students_data, &render_student_with_stats(&1))}
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
      updated_at: student.updated_at,
      guardians: render_guardians(student.guardians)
    }
  end

  defp render_student_with_stats(%{student: student, total_today: total, completed_today: completed}) do
    render_student(student)
    |> Map.merge(%{
      activities_total_today: total,
      activities_completed_today: completed
    })
  end

  def index(%{students: students}) do
    #Mapeia cda aluno na lista usando a função auxiliar render_student
    %{data: Enum.map(students, &render_student(&1))}
  end

  defp render_guardians(%Ecto.Association.NotLoaded{}), do: []
  defp render_guardians(guardians) when is_list(guardians) do
    Enum.map(guardians, fn g ->
      %{
        id: g.id,
        user_id: g.user_id,
        name: g.user.full_name,
        email: g.user.email,
        avatar_id: g.user.avatar_id
      }
    end)
  end
  defp render_guardians(_), do: []


end
