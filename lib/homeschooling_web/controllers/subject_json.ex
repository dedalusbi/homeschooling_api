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
      teaching_materials: subject.teaching_materials,
      aulas_realizadas: Map.get(subject, :total_given, 0),
      participacao: Map.get(subject, :participation, 0),
      assessments: render_assessments(subject.assessments)
    }
  end


  defp get_report_text(nil), do: nil
  defp get_report_text(%Ecto.Association.NotLoaded{}), do: nil
  defp get_report_text(%SubjectCompletion{}=completion), do: completion.final_report


  defp render_assessments(assessments) when is_list(assessments) do
    Enum.map(assessments, fn a ->
      %{
        id: a.id,
        title: a.title,
        assessment_date: a.assessment_date,
        grade: a.grade,
        notes: a.notes,
        attachments: render_attachments_list(a.attachments)
      }
    end)
  end
  defp render_assessments(_), do: []

  defp render_attachments_list(%Ecto.Association.NotLoaded{}), do: []
  defp render_attachments_list(attachments) when is_list(attachments) do
    Enum.map(attachments, fn att ->
      %{
        id: att.id,
        file_url: att.file_url,
        file_type: att.file_type,
        file_name: att.file_name
      }
    end)
  end
  defp render_attachments_list(_), do: []



end
