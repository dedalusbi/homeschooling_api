defmodule Homeschooling.Workers.SendUpcomingClassNotification do
  use Oban.Worker, queue: :notifications, max_attempts: 3
  alias Homeschooling.Accounts
  alias Homeschooling.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"schedule_id" => schedule_id}}) do
    #Busca a aula, o aluno e os responsáveis
    schedule = Accounts.get_schedule!(schedule_id) |> Repo.preload([:subject, student: [guardians: :user]])

    #Mensagem ácida de lembrete
    title = "Aula começando: #{schedule.subject.name}"
    body = "Largue o videogame. A aula de #{schedule.subject.name} começa em breve."

    #Coleta tokens de todos os responsáveis
    tokens =
      schedule.student.guardians
      |> Enum.map(& &1.user.id)
      |> Accounts.list_device_tokens_for_users()

    #Envia  para o FCM
    send_fcm(tokens, title, body)

    :ok
  end

  defp send_fcm([], _, _), do: :ok
  defp send_fcm(tokens, title, body) do
    # Usamos IO.inspect com label GRANDE para você não perder no log
    IO.inspect("--------------- PUSH NOTIFICATION ---------------")
    IO.inspect("Para: #{length(tokens)} dispositivos")
    IO.inspect("Título: #{title}")
    IO.inspect("Corpo: #{body}")
    IO.inspect("-------------------------------------------------")
    #Simulação. na prática precisamos da chave do servidor do firebase
    #Req.post("https://fcm.googleapis.com/fcm/send", json: %{...})
  end

end
