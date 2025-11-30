defmodule HomeschoolingWeb.AssessmentJSON do
  alias Homeschooling.Accounts.Assessment


  def show(%{assessment: assessment}) do
    %{data: data(assessment)}
  end


  def index(%{assessments: assessments}) do
    %{data: for(assessment <- assessments, do: data(assessment))}
  end




  defp data(%Assessment{} = assessment) do
    %{
      id: assessment.id,
      subject_id: assessment.subject_id,
      title: assessment.title,
      assessment_date: assessment.assessment_date,
      grade: assessment.grade,
      notes: assessment.notes,
      attachments: render_attachments(assessment.attachments),
      inserted_at: assessment.inserted_at,
      updated_at: assessment.updated_at
    }
  end

  defp render_attachments(%Ecto.Association.NotLoaded{}), do: []
  defp render_attachments(attachments) when is_list(attachments) do
    Enum.map(attachments, fn att ->
      %{
        id: att.id,
        file_url: att.file_url,
        file_type: att.file_type,
        file_name: att.file_name
      }
    end)
  end
  defp render_attachments(_), do: []

end
