defmodule HomeschoolingWeb.SubjectJSON do
  alias Homeschooling.Accounts.Subject

  def index(%{subjects: subjects}) do
    %{data: Enum.map(subjects, &render_subject(&1))}
  end

  def subject(%{subject: subject}) do
    %{data: render_subject(subject)}
  end

  defp render_subject(%Subject{}=subject) do
    %{
      id: subject.id,
      student_id: subject.student_id,
      name: subject.name,
      description: subject.description,
      status: subject.status,
      inserted_at: subject.inserted_at,
      #adicionar lógica de contagem de aulas
      #por enquanto: placeholder
      aulas_concluidas: Enum.random(5..15),
      aulas_totais: 20,
      progresso: Enum.random(30..90)
    }
  end

end
