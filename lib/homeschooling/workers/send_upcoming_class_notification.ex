defmodule Homeschooling.Workers.SendUpcomingClassNotification do
  use Oban.Worker, queue: notifications, max_attempts: 3
  alias Homeschooling.Accounts
  alias Homeschooling.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"schedule_id" => schedule_id}}) do
    #Busca a aula, o aluno e os responsáveis
    schedule = Accounts.get_schedule!(schedule_id) |> Repo.preload([student: [guardians: :user]])

    #Mensagem ácida de lembrete
    title = "Aula começando: #{schedule.subject.name}"
    body = "Largue o videogame. A aula de #{schedule.subject.name} começa em breve."

  end
end
