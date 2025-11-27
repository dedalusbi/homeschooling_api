defmodule HomeschoolingWeb.SubjectJSON do
  alias Homeschooling.Accounts.Subject
  alias Homeschooling.Accounts.SubjectCompletion

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
      completion_report: get_report_text(subject.completion),
      aulas_concluidas: Map.get(subject, :completed, 0),
      aulas_totais: Map.get(subject, :total, 0),
      progresso: Map.get(subject, :progress, 0),
      history: Map.get(subject, :history),
      teaching_materials: subject.teaching_materials
    }
  end


  defp get_report_text(nil), do: nil
  defp get_report_text(%Ecto.Association.NotLoaded{}), do: nil
  defp get_report_text(%SubjectCompletion{}=completion), do: completion.final_report

end
