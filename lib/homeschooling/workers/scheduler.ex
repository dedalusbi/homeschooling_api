defmodule Homeschooling.Workers.Scheduler do
  use Oban.Worker, queue: :default, unique: [period: 60]
  import Ecto.Query
  alias Homeschooling.Repo
  alias Homeschooling.Accounts.ScheduleEntry
  alias Homeschooling.Workers.SendUpcomingClassNotification

  @impl Oban.Worker
  def perform(_args) do
    #Definimos o "agora" e o "alvo"
    now = DateTime.utc_now()
    target_time = Time.add(Time.utc_now(), 30, :minute)

    #margem de erro (cron roda a cada 5 minutos)
    window_start= Time.add(target_time, -180, :second)
    window_end= Time.add(target_time, 180, :second)

    #query: aulas de hoje, onde o horário cai na janela estipulada
    entries =
      from(s in ScheduleEntry,
        where: s.start_date == ^DateTime.to_date(now),
        where: s.start_time >= ^window_start and s.start_time < ^window_end
      )
      |> Repo.all()

    #Dispara os jobs individuais de notificação
    Enum.each(entries, fn schedule ->
      %{schedule_id: schedule.id}
      |> SendUpcomingClassNotification.new()
      |> Oban.insert()
    end)

    :ok

  end
end
