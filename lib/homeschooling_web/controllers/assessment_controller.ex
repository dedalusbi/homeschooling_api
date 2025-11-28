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
end
