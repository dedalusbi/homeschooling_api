defmodule HomeschoolingWeb.AssessmentController do
  use HomeschoolingWeb, :controller
  alias Homeschooling.Accounts

  def create(conn, %{"subject_id" => subject_id, "assessment" => assessment_params}) do
    current_user = conn.assigns.current_user

    case Accounts.create_assessment(current_user, subject_id, assessment_params) do
      {:ok, assessment} ->
        conn
        |> put_status(:created)
        |> json(%{data: assessment})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Matéria não encontrada"})
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: HomeschoolingWeb.UserController.format_errors(changeset)})
    end
  end


  #GET /api/assessments/upload_url
  def upload_url(conn, %{"filename" => filename, "type" => type}) do
    {:ok, data} = Accounts.generate_assessment_presigned_url(filename, type)
    json(conn, %{data: data})
  end

  #POST /api/assessments/:id/attachments
  def create_attachment(conn, %{"id" => log_id, "attachment" => attachment_params}) do
    case Accounts.create_assessment_attachment(log_id, attachment_params) do
      {:ok, attachment} ->
        conn |> put_status(:created) |> json(%{data: attachment})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: changeset})
    end
  end

  def update(conn, %{"id" => id, "assessment" => assessment_params}) do
    current_user = conn.assigns.current_user

    case Accounts.update_assessment(current_user, id, assessment_params) do
      {:ok, assessment} ->
        render(conn, :show, assessment: assessment)
        # Nota: Se não tiver view específica, pode usar json(conn, %{data: assessment})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Avaliação não encontrada"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: HomeschoolingWeb.UserController.format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case Accounts.delete_assessment(current_user, id) do
      {:ok, _assessment} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Avaliação não encontrada"})
    end
  end

end
