defmodule Homeschooling.Accounts do
  import Ecto.Query, warn: false
  alias Homeschooling.Repo
  alias Homeschooling.Mailer
  alias Homeschooling.Accounts.User
  alias Homeschooling.Accounts.PasswordResetToken
  alias Homeschooling.Accounts.EmailVerificationToken
  alias Homeschooling.Accounts.{Student, Guardian, Subject, SubjectCompletion, ScheduleEntry, DailyLog, LogAttachment}
  alias ExAws.S3

  @default_avatars [
    "imagemavatar1.png",
    "imagemavatar2.png",
    "imagemavatar3.png",
    "imagemavatar4.png",
    "imagemavatar5.png",
    "imagemavatar6.png",
    "imagemavatar7.png",
    "imagemavatar8.png",
    "imagemavatar9.png",
    "imagemavatar10.png",
  ]

  # Registra um novo usuário como não verificado, gera um token de verificação e envia o email correspondente.
  def register_user(attrs) do
    attrs_with_avatar = Map.put(attrs, "avatar_id", Enum.random(@default_avatars))
    # Usando Ecto.Multi() para agrupar várias operações de base de dados que devem acontecer juntar (ou falhar juntas)
    Ecto.Multi.new()
    # 1. Tentando inserir o usuário utilizando o changeset de registro
    |> Ecto.Multi.insert(:user, %User{} |> User.registration_changeset(attrs_with_avatar))
    # 1. Se o usuário foi inserido, gera e insere o token de verificação
    |> Ecto.Multi.run(:verification_token, fn repo, %{user: user} ->
      generate_and_insert_verification_token(repo, user) end)
    |> Repo.transaction()
    |> case do
      #Se tudo correu bem...
      {:ok, %{user: user, verification_token: raw_token}} ->
        #Envia o email de verificação
        send_verification_email(user, raw_token)
        #Retorna sucesso (mas indicando que a verificação é necessária)
        {:ok, :verification_email_sent, user} #retorna o user para possível uso futuro

      #Se houve um erro
      {:error, _failed_operation, error_reason, _changes_so_far} ->
        {:error, error_reason}
    end
  end


  #Função auxiliar para gerar e inserir o token (usada no ecto.Multi)
  defp generate_and_insert_verification_token(repo, user) do
    with(
      #Gera um token único (similar ao de reset de senha)
      {:ok, raw_token} <- generate_unique_verification_token(),
      #Define expiração
      expires_at <- DateTime.add(DateTime.utc_now(), 24*3600, :second),
      #Cria o changeset para o token
      {:ok, changeset} <- {:ok, %EmailVerificationToken{} |> EmailVerificationToken.changeset(%{user_id: user.id, expires_at: expires_at}, raw_token)},
      #Tenta inserir o token (hash)
      {:ok, _token_struct} <- repo.insert(changeset)
    )do
      {:ok, raw_token}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  defp generate_unique_verification_token(retries \\ 5)
  defp generate_unique_verification_token(0), do: {:error, :token_generation_failed}
  defp generate_unique_verification_token(retries) do
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    token_hash = :crypto.hash(:sha256, raw_token) |> Base.encode64(padding: false) |> binary_part(0,43)
    unless Repo.get(EmailVerificationToken, token_hash) do
      {:ok, raw_token}
    else
      generate_unique_verification_token(retries-1)
    end
  end


  #Função para enviar o email de verificação
  defp send_verification_email(user, raw_token) do
    #Construir a URL do frontend que receberá o token
    verification_url = "http://localhost:8100/auth/verify-email?token=#{raw_token}"
    #Cria o email
    email = Swoosh.Email.new()
    |> Swoosh.Email.to({user.full_name, user.email})
    |> Swoosh.Email.from({"EduCasa App", "dedalusbi@gmail.com"})
    |> Swoosh.Email.subject("Confirme seu email - App Homeschooling")
    |> Swoosh.Email.html_body("""
      <p>Olá #{user.full_name}, </p>
      <p>Bem-vindo ao EduCasa! Para ativar sua conta, por favor clique no link abaixo:</p>
      <p><a href="#{verification_url}">Verificar meu email</a></p>
      <p>Este link expira em 24 horas.</p>
    """)
    Mailer.deliver(email)
  end


  #Reenvia o email de verificação para um usuário não verificado.
  #invalida tokens de vrificação anteriores para este usuário
  def resend_verification_email(email) do
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        #Verifica se o utilizador já não está verificado
        if is_nil(user.verified_at) do
          #Usuário encontrado e não verificado. Procede com o reenvio. Inicia uma transação para garantir que a remoção do token
          #antigo e a criação do novo aconteçam juntas
          Repo.transaction(fn ->
              #Remove quaisquer tokens de verificação anteriores para este usuário
              Repo.delete_all(
                from t in EmailVerificationToken, where: t.user_id == ^user.id
              )

              #Gera e insere um novo token de verificação
              case generate_and_insert_verification_token(Repo, user) do
                {:ok, raw_token} ->
                  send_verification_email(user, raw_token)
                  {:ok, :email_resent}

                  {:error, reason} ->
                    Repo.rollback({:error_generating_token, reason})
              end
          end)

          #Analise o resultado da transação
          |> case do
            {:ok, email_resent} ->
              {:ok, "Email de verificação reenviado."}
            {:error, {:error_generating_token, reason}} ->
              IO.inspect(reason, label: "Erro ao gerar token no reenvio")
              {:error, :internal_server_error}
            _ ->
              {:error, :internal_server_error}
          end
        else
          #Se usuário já verificado, não faz nada, retorna sucesso genérico
          {:ok, "Email já verificado ou solicitação processada."}
        end

      #Se o email não foi encontrado
      nil ->
        #Retorna sucesso genérico para não vazar informação se o email existe
        {:ok, "Solicitação de reenvio processada."}

    end
  end



  #Verifica um token de email, marca o usuário como verificado e remove o token
  def verify_user_email(token) do
    # Calcula o hash do token recebido para procurar na base de dados
    token_hash = :crypto.hash(:sha256, token) |> Base.encode64(padding: false) |> binary_part(0, 43)

    # Inicia uma transação para garantir atomicidade
    Repo.transaction(fn ->
      # Procura o token pelo hash e pré-carrega o utilizador
      case Repo.get(EmailVerificationToken, token_hash) |> Repo.preload(:user) do
        # --- Padrão 1: Token e utilizador encontrados ---
        %EmailVerificationToken{expires_at: expires_at, user: %User{} = user} ->
          # Verifica se o token NÃO expirou (data atual é ANTES da expiração)
          if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
            # Token válido! Marca o utilizador como verificado
            user
            |> Ecto.Changeset.change(%{verified_at: DateTime.utc_now() |> DateTime.truncate(:second)})
            |> Repo.update!() # Atualiza o utilizador

            # Remove o token de verificação (usamos `delete!` pois esperamos que ele exista)
            Repo.delete!(Repo.get!(EmailVerificationToken, token_hash))

            # Retorna sucesso dentro da transação
            {:ok, user}
          else
            # Token EXPIRADO! Remove-o e desfaz a transação
            Repo.delete!(Repo.get!(EmailVerificationToken, token_hash))
            Repo.rollback(:token_expired) # Retorna :token_expired como erro da transação
          end

        # --- Padrão 2: Token NÃO encontrado ---
        nil ->
          # Desfaz a transação e retorna :invalid_token como erro
          Repo.rollback(:invalid_token)

        # NÃO HÁ 'else' AQUI! O 'case' termina após os padrões '->'
      end
    end)
    # O resultado da transação será {:ok, user} ou {:error, :token_expired} ou {:error, :invalid_token}
  end


  def login_user(email, password) do
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        cond do
          is_nil(user.verified_at) ->
            {:error, :email_not_verified}

          Pbkdf2.verify_pass(password, user.password_hash) ->
            generate_jwt(user)

          true ->
            {:error, :invalid_credentials}
        end
      nil ->
      {:error, :invalid_credentials}
    end

  end

  @doc """
  Gets a single user by ID.
  """
  def get_user_by_id(id) do
    Repo.get(User, id)
  end


  #Função privada auxiliar para gerar o token JWT
  defp generate_jwt(user) do
    claims = %{
      "sub" => user.id,
      "exp" => DateTime.utc_now() |> DateTime.add(60*60*24*7) |> DateTime.to_unix()
    }

    key = Application.fetch_env!(:homeschooling, :jwt_secret)

    signer = Joken.Signer.create("HS256", key)

    Joken.encode_and_sign(claims, signer)
  end


  #Gera um token de reset de senha, guarda-o (hash) e envia o email
  def generate_and_send_reset_token(email) do
    with( # Encontra o usuário pelo email
         %User{} = user <- Repo.get_by(User, email: email) |> handle_user_not_found(),
         # Gera um token seguro e aleatório
         {:ok, raw_token} <- generate_unique_reset_token(),
         # Define a data de expiração (1 hora a partir de agora)
         expires_at = DateTime.add(DateTime.utc_now(), 3600, :second),
         # Cria o changeset para o token (que inclui o hashing)
         changeset =
           PasswordResetToken.changeset(
             %{user_id: user.id, expires_at: expires_at},
             raw_token
           ),
         # Tenta inserir o token no banco de dados
         {:ok, _reset_token_struct} <- Repo.insert(changeset)
        )do # CORRIGIDO: Insere aqui
      # Se tudo correu bem, envia o email com o token bruto
      send_password_reset_email(user, raw_token)
      {:ok, "Email de recuperação enviado com sucesso."}
    else
      # Se o usuário não foi encontrado (tratado por handle_user_not_found)
      {:error, :user_not_found} ->
        {:error, :user_not_found}

      # Se houve erro ao gerar o token
      {:error, :token_generation_failed} ->
        {:error, :token_generation_failed}

      # Se houve erro ao inserir o token
      # CORRIGIDO: Typo chageset -> changeset
      {:error, changeset} ->
        {:error, {:token_insertion_failed, changeset}}
    end
  end


  # Função auxiliar para o 'with' tratar o 'nil' de Repo.get_by
  defp handle_user_not_found(nil), do: {:error, :user_not_found}
  defp handle_user_not_found(user), do: user

  defp generate_unique_reset_token(retries \\ 5)
  defp generate_unique_reset_token(0), do: {:error, :token_generation_failed}
  defp generate_unique_reset_token(retries) do
    raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    token_hash = :crypto.hash(:sha256, raw_token) |> Base.encode64(padding: false) |> binary_part(0,43)
    unless Repo.get(PasswordResetToken, token_hash) do
      {:ok, raw_token}
    else
      generate_unique_reset_token(retries-1)
    end
  end


  defp send_password_reset_email(user, raw_token) do
    #Construir a URL do frontend que receberá o token
    reset_url = "http://localhost:8100/auth/reset-password?token=#{raw_token}"
    #Cria o email
    email = Swoosh.Email.new()
    |> Swoosh.Email.to({user.full_name, user.email})
    |> Swoosh.Email.from({"EduCasa App", "dedalusbi@gmail.com"})
    |> Swoosh.Email.subject("Recuperação de senha - App Homeschooling")
    |> Swoosh.Email.html_body("""
      <p>Olá #{user.full_name}, </p>
      <p>Recebemos um pedido para redefinir a sua senha.</p>
      <p>Clique no link abaixo para criar uma nova senha:</p>
      <p><a href="#{reset_url}">Redefinir Senha</a></p>
      <p>Este link expira em 1 hora.</p>
      <p>Se não solicitou esta alteração, favor ignorar este email.</p>
    """)
    Mailer.deliver(email)
  end

  #Redefine a senha do usuário se o token for válido
  def reset_password(token, new_password, confirm_password) do
    # Validações básicas da nova senha
    cond do
      new_password != confirm_password ->
        {:error, :passwords_mismatch}

      String.length(new_password) < 6 ->
        {:error, :password_too_short}

      true ->
        # Calcula o hash do token recebido para procurar na base de dados
        token_hash = :crypto.hash(:sha256, token) |> Base.encode64(padding: false) |> binary_part(0, 43)
        # procura o token na base de dados e pré-carrega o usuário associado
        case Repo.get(PasswordResetToken, token_hash) |> Repo.preload(:user) do
          # Se encontrou o token...
          # CORRIGIDO: Match no token, acessa .user depois
          %Homeschooling.Accounts.PasswordResetToken{expires_at: expires_at} = reset_token ->
            # Verifica se o usuário foi carregado (pode falhar se user_id for inválido)
            case reset_token.user do
              %User{} = user ->
                # Verifica se o token não expirou
                if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
                  # Token válido! Atualiza a senha do usuário
                  result =
                    user
                    |> User.password_reset_changeset(%{password: new_password})
                    |> Repo.update()

                  # Deleta o token APÓS usar o ID dele
                  Repo.delete!(reset_token)

                  case result do
                    {:ok, _user} -> {:ok, "Senha redefinida com sucesso."}
                    {:error, changeset} -> {:error, {:password_update_failed, changeset}}
                  end
                else
                  # Token expirado. Remover
                  Repo.delete!(reset_token)
                  {:error, :token_expired}
                end

              # Caso o preload(:user) falhe (raro, mas possível)
              nil ->
                Repo.delete!(reset_token) # Limpa o token órfão
                {:error, :user_not_found_for_token}
            end

          # Se o token não foi encontrado...
          nil ->
            {:error, :invalid_or_expired_token}
        end
    end
  end


  #Cria um novo aluno para o usuário fornecido,
  #respeitando os limites do plano e criando a ligação guardian
  def create_student(%User{}=user, attrs) do
    # 1. Veriicar limite do plano
    # Primeiro, contamos quantos alunos o usuário já tem
    current_student_count = from(g in Guardian, where: g.user_id == ^user.id)
    |> Repo.aggregate(:count, :student_id)

    #Define os limites (pode vir da config ou estar hardcoded)
      #busca o mapa de limites definido em config.exe
    all_limits = Application.get_env(:homeschooling, :subscription_limits, %{})
      #map.get/3 busca a chave; se não encontrar, retorna o valor padrão 1
    limit = Map.get(all_limits, user.subscription_tier, 1)


    # --- lógica de avatar
    #escolhe um avatar aleatório da lista
    random_avatar_id=Enum.random(@default_avatars)
    #Adicina o avatar_id aos atributos antes de enviar para o changeset
    attrs_with_avatar = Map.put(attrs, "avatar_id", random_avatar_id)


    #Verifica se o limite foi atingido
    if current_student_count >= limit do
      {:error, :student_limit_reached}
    else
      #Limite OK, tenta criar o aluno e a ligação guardian
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:student_insert, Student.changeset(%Student{}, attrs_with_avatar))
      |> Ecto.Multi.insert(:guardian_insert, fn %{student_insert: student} ->
        Guardian.changeset(%Guardian{}, %{user_id: user.id, student_id: student.id})
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{student_insert: student, guardian_insert: _guardian}} ->
          {:ok, student}
        {:error, _operation_name, error_reason, _changes_so_far} ->
          IO.inspect(error_reason, label: "!!! Erro na transação  create_student ")
          if  is_struct(error_reason, Ecto.Changeset) do
            {:error, error_reason}
          else
            {:error, error_reason}
          end
      end
    end
  end


  #--- RETORNA A LISTA DE TODOS OS ALUNOS ASSOCIADOS A UM USUÁRIO ESPECÍFICO ---
  def list_students_for_user(%User{} = user) do

    today = Date.utc_today()
    day_of_week = Date.day_of_week(today)
    #Ajuste para 0-6
    db_day_of_week = if day_of_week == 7, do: 0, else: day_of_week

    #Esta query faz um JOIN entre students e guardians para encontrar todos os students onde o user_id na tabela
    #guardians corresponde ao ID do usuário
    query =
      from s in Student,
      join: g in Guardian, on: g.student_id == s.id,
      where: g.user_id == ^user.id,
      #subquery para total de aulas hoje
      #Conta schedule_entries que são válidas para hoje
      left_join: total_today in subquery(
        from se in ScheduleEntry,
        where:
          (se.specific_date == ^today) or
          (
            se.day_of_week == ^db_day_of_week and
            se.start_date <= ^today and
            (is_nil(se.end_date) or se.end_date >= ^today)
          ),
        group_by: se.student_id,
        select: %{student_id: se.student_id, count: count(se.id)}
      ), on: total_today.student_id == s.id,
      #subquery para aulas concluídas hoje
      left_join: completed_today in subquery(
        from l in DailyLog,
        where: l.log_date == ^today and l.status == :completed,
        join: se in ScheduleEntry, on: l.schedule_entry_id == se.id,
        group_by: se.student_id,
        select: %{student_id: se.student_id, count: count(l.id)}
      ), on: completed_today.student_id == s.id,
      #Seleciona os dados + contagens
      select: %{
        student: s,
        total_today: coalesce(total_today.count, 0),
        completed_today: coalesce(completed_today.count, 0)
      }

    #Executa a query e retorna a lista de mapas
    Repo.all(query)

    #Retorna uma lista vazia se o usuário não tiver alunos

  end

  #Busca um aluno específico pelo IS, mas apenas se ele pertencer ao usuário
  def get_student_by_id_for_user(%User{} = user, student_id) do
  #Query que busca o student pelo ID e verifica se existe uma ligação
  #na tabela guardians com o user_id do utilizador atual
    query =
      from s in Student,
      join: g in Guardian, on: g.student_id == s.id,
      where: s.id == ^student_id and g.user_id == ^user.id,
      select: s

    Repo.one(query)
  end


  #Atualiza um aluno existente, se ele pertencer ao usuário logado
  #Retorna {:ok, student} em caso de sucesso,
  #{:error, :not_found} se o aluno não existir ou não pertencer ao usuário,
  #{:error, changeset} se os dados forem inválidos
  def update_student_for_user(%User{}=user, student_id, attrs) do

    #Remove avatar_id e profile_picture_url, o usuário não deve poder mudar diretamente
    attrs_cleaned = Map.drop(attrs, ["avatar_id", "profile_picture_url"])

    case get_student_by_id_for_user(user, student_id) do
      %Student{} = student ->
        student
        |> Student.changeset(attrs_cleaned)
        |> Repo.update()
        #Repo.update() retorna {:ok, student} ou {:error, changeset}

      #Se não encontrou ou não tem permissão
      nil ->
        {:error, :not_found}
    end
  end

  #Remove um aluno pelo ID, mas apenas se ele pertencer ao usuário fornecido.
  def delete_student_for_user(%User{}=user, student_id) do
    case get_student_by_id_for_user(user, student_id) do
      %Student{} = student ->
        Repo.delete(student)

      #Se não encontrou ou não tem permissão
      nil ->
        {:error, :not_found}
    end
  end

  #Gera uma URL pré-assinada para o upload de uma foto de perfil de aluno.
  #Verifica se o utilizador tem permissão sobre o  aluno
  def generate_student_photo_upload_url(%User{}=user, student_id, file_type) do
    #Verifica se o usuário tem permissão sobre o aluno
    case get_student_by_id_for_user(user, student_id) do
      %Student{} =student ->
        #Define o nome do arquivo no S3 (ex.: uploads/students/UUID/profile_pic.jpg)
        #Usar o ID do aluno garante que é único e oganizado
        extension = String.split(file_type,"/") |> List.last() |> String.trim()
        s3_key = "/uploads/students/#{student.id}/profile.#{extension}"

        #Obtém o nome do bucket da configuração
        bucket = "educasa-uploads"

        #Gera a url pré-assinada para um PUT, válida por 5 minutos (300 segundos)
        case S3.presigned_url(:put_object, s3_key, expires_in: 300, content_type: file_type) do
          {:ok, upload_url} ->
            #Gera o URL público que será guardado na base de dados
            #(assumindo que o bucker está configurado para leitura pública)
            public_url = "https://#{bucket}.s3.amazonaws.com/#{s3_key}"
            {:ok, %{upload_url: upload_url, public_url: public_url}}
          {:error, reason} ->
            {:error, {:s3_error, reason}}
        end

      nil ->
        {:error, :not_found}
    end
  end


  #Retorna a lista de matérias para um aluno específico,
  #opcionalmente filtrada pelo status
  def list_subjects_for_student(%Student{}=student, filters) do
    #Começa a query pela tabela `subjects`
    query = from s in Subject, where: s.student_id == ^student.id

    #Aplica o filtro de status, se ele for fornecido
    query =
      case Map.get(filters, "status") do
        nil ->
          query
        "all" ->
          query
        status ->
          "Converte a string 'actve' para o átomo ':active'"
          status_atom = String.to_atom(status)
          from s in query, where: s.status == ^status_atom
      end


    #Ordena por nome da matéria
    query = from s in query, order_by: s.name

    #Executa a query e retorna a lista de matérias
    Repo.all(query)
  end


  #Cria uma nova matéria para um aluno específico, se o usuário tiver permissão
  def create_subject_for_student(%User{}=user, student_id, attrs) do
    #Verifica se o usuário tem permissão sobre o aluno
    case get_student_by_id_for_user(user, student_id) do
      %Student{} = student ->
        #Prepara os atributos e associa o student_id
        subject_attrs = Map.put(attrs, "student_id", student.id)
        #Cria o changeset
        %Subject{}
        |> Subject.changeset(subject_attrs)
        |> Repo.insert()

      nil ->
        {:error, :not_found}
    end
  end

  #Busca uma matéria especíica pelo seu ID, mas apenas se o usuário logado
    #for um responsável pelo aluno ao qual a matéria pertence
  def get_subject_by_id_for_user(%User{}=user, subject_id) do
    query=
      from s in Subject,
      join: st in Student, on: s.student_id == st.id,
      join: g in Guardian, on: g.student_id == st.id,
      where: s.id == ^subject_id and g.user_id == ^user.id,
      select: s

    case Repo.one(query) do
      nil ->
        nil
      %Subject{}=subject ->
        Repo.preload(subject, :completion)
    end
  end


  #Atualiza uma matéria existente, se ela pertencer ao usuário fornecido.
  def update_subject_for_user(%User{}=user, subject_id, attrs) do
    #Busca a matéria garantindo que o usuário tenha permissão sobre ela
    case get_subject_by_id_for_user(user, subject_id) do
      %Subject{}=subject ->
        subject
        |> Subject.changeset(attrs)
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end


  #Finaliza uma matéria:atualiza o status e cria o relatório de conclusão
  #Verifica se o usuário tem permissão
  def complete_subject_for_user(%User{}=user, subject_id, report_attrs) do
    case get_subject_by_id_for_user(user, subject_id) do
      %Subject{status: :active}=subject ->
        completion_attrs = Map.merge(report_attrs, %{
          "subject_id" => subject_id,
          "completion_date" => Date.utc_today()
        })

        Ecto.Multi.new()
        #atualiza o status da matéria para completed
        |> Ecto.Multi.update(:update_subject_status,
          Ecto.Changeset.change(subject, %{status: :completed}))
        #Insere o novo relatório de conclusão
        |> Ecto.Multi.insert(:insert_completion_report,
          SubjectCompletion.changeset(%SubjectCompletion{}, completion_attrs)
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{update_subject_status: updated_subject, insert_completion_report: _report}} ->
            {:ok, updated_subject}

          {:error, :insert_completion_report, changeset, _changes_so_far} ->
            {:error, changeset}

          {:error, _operation, reason, _changes} ->
            {:error, reason}

          end

      %Subject{status: :completed} ->
        {:error, :already_completed}

      nil ->
        {:error, :not_found}
    end
  end


  #Reativa uma matéria finalizada: atualzia o status para actve
  def reactivate_subject_for_user(%User{}=user, subject_id) do
    #Busca a matéria garantindo que o usuário tenha permissão sobre ela
    case get_subject_by_id_for_user(user, subject_id) do
      %Subject{status: :completed}=subject ->
        Ecto.Multi.new()
        |> Ecto.Multi.delete_all(:remove_report,
           (from sc in SubjectCompletion, where: sc.subject_id == ^subject.id)
         )
        |> Ecto.Multi.update(:update_subject_status,
          Ecto.Changeset.change(subject, %{status: :active})
        )
        |> Repo.transaction()
        |> case do
          {:ok, %{update_subject_status: reactivated_subject}} ->
            {:ok, reactivated_subject}

          {:error, _operation, reason, _changes} ->
            {:error, reason}
          end

      %Subject{status: :active} ->
        {:error, :already_active}


      nil ->
        {:error, :not_found}
    end
  end



  #Remove permanentemente uma matéria e todos os seus dados associados (aulas, avaliações, relatórios)
  def delete_subject_for_user(%User{}=user, subject_id) do

    case get_subject_by_id_for_user(user, subject_id) do
      %Subject{}=subject ->
        Repo.delete(subject)

      nil ->
        {:error, :not_found}
    end
  end


  #Retorna a lista de todas as entradas do cronograma (aulas recorrentes)
  #para um aluno específico, se o usuário tiver permissão
  def list_schedule_for_student(%User{}=user, student_id, filters \\ %{}) do

    week_start = Map.get(filters, "week_start")
    week_end = Map.get(filters, "week_end")

    if is_nil(week_start) or is_nil(week_end) do
      {:error, :data_range_required}
    end

    case get_student_by_id_for_user(user, student_id) do

      %Student{}=student ->
        query=
          from se in ScheduleEntry,
          where: se.student_id == ^student.id,
          where:
            #1. É um evento único dentro da semana
            (se.specific_date >= ^week_start and se.specific_date <= ^week_end)
            or
            #2. É um recorrente ativo na semana
            (
            not is_nil(se.day_of_week) and
            se.start_date <= ^week_end and
            (is_nil(se.end_date) or se.end_date >= ^week_start)
            ),
          join: s in Subject, on: s.id == se.subject_id,
          left_join: log in DailyLog, on: log.schedule_entry_id == se.id
                                            and log.log_date >= ^week_start
                                            and log.log_date <= ^week_end,
          left_join: u in User, on: u.id == se.assigned_guardian_id,
          order_by: [se.day_of_week, se.start_time],
          select: %{
            id: se.id,
            student_id: se.student_id,
            subject_id: se.subject_id,
            subject_name: s.name,
            responsible_avatar_id: u.avatar_id,
            student_name: ^student.name,
            assigned_guardian_id: se.assigned_guardian_id,
            day_of_week: se.day_of_week,
            activities: se.activities,
            start_date: se.start_date,
            status: log.status,
            log_id: log.id,
            log_notes: log.notes,
            end_date: se.end_date,
            start_time: se.start_time,
            end_time: se.end_time,
            is_recurring: not is_nil(se.day_of_week),
            specific_date: se.specific_date,
            excluded_dates: se.excluded_dates,
            recurrence_group_id: se.recurrence_group_id
          }

          #Aplica o filtro "apenas minhas aulas" se "only_mine" for true

          query =
            if Map.get(filters, "only_mine", "false") == "true" do
              query |> where([se, s], se.assigned_guardian_id == ^user.id)
            else
              query
            end

        {:ok, Repo.all(query)}

      nil ->
        {:error, :not_found}

    end
  end

  #Cria múltiplas entradas no cronograma (aulas) para um aluno,
  #uma para cada dia da semana fornecido.
  def create_schedule_entries(%User{}=user, student_id, attrs) do

    is_recurring = case Map.get(attrs, "is_recurring") do
      true -> true
      "true" -> true
      _ -> false

    end

    case get_student_by_id_for_user(user, student_id) do

      %Student{} =student ->

        subject_id = attrs["subject_id"]
        subject = Repo.get(Subject, subject_id)

        if subject && subject.student_id == student_id do
            #Prepara os dados para validação
          #Precisamos saber as datas e horários para verificar conflitos
          with {:ok, new_start_time} <- Time.from_iso8601(attrs["start_time"] <> ":00"),
              {:ok, new_end_time} <- Time.from_iso8601(attrs["end_time"] <> ":00") do

                conflict_scope =
                  if is_recurring do
                    #Para recorrente: verificamos os dias da semana selecionados
                    days_of_week_raw = Map.get(attrs, "days_of_week", [])
                    days = case days_of_week_raw do
                      list when is_list(list) ->
                        Enum.map(list, fn
                          s when is_binary(s) -> String.to_integer(s)
                          i when is_integer(i) -> i
                          _ -> nil
                        end)
                        |> Enum.reject(&is_nil/1)
                      _ ->
                        []
                    end

                    if Enum.empty?(days) do
                      {:error, :missing_days_of_week}
                    else
                      start_date = Date.from_iso8601!(attrs["start_date"])
                      end_date = if attrs["end_date"] && attrs["end_date"] != "", do: Date.from_iso8601!(attrs["end_date"]), else: nil
                      {:recurring, days, start_date, end_date}
                    end

                  else
                    #Para única: verificamos a data específica
                    date = Date.from_iso8601!(attrs["specific_date"])
                    {:single, date}
                  end

                #executa a verificação de conflito unificada
                if has_conflict?(student_id, new_start_time, new_end_time, conflict_scope) do
                  {:error, {:schedule_conflict, []}}
                else
                  perform_schedule_creation(student, attrs, is_recurring)
                end
            else

              _ -> {:error, :invalid_time_format}

          end
        else
          {:error, :subject_mismatch}
        end



      nil ->
        {:error, :not_found}
    end
  end


  def get_schedule_entry_for_user(%User{}=user, entry_id) do
    query=
      from se in ScheduleEntry,
      join: s in Student, on: se.student_id == s.id,
      join: g in Guardian, on: g.student_id == s.id,
      where: se.id == ^entry_id and g.user_id == ^user.id,
      select: se

    case Repo.one(query) do
      nil -> {:error, :not_found}
      entry ->

        entry = Repo.preload(entry, [:student, :subject])

        is_recurring_value = not is_nil(entry.day_of_week)
        entry = %{entry | is_recurring: is_recurring_value}

      # -- preencher active_days - buscar entries "irmãs" -- (criadas na mesma recorrência) --
        entry_with_days = if entry.recurrence_group_id do
          #Busca todos os dias da semana associados a este grupo
          days = Repo.all(
            from se in ScheduleEntry,
            where: se.recurrence_group_id == ^entry.recurrence_group_id,
            select: se.day_of_week
          )
          #Coloca no campo virtual
          %{entry | active_days: days}
        else
          #Se não tem grupo, o dia ativo é o próprio dia da aula
          days = if entry.day_of_week, do: [entry.day_of_week], else: []
          %{entry | active_days: days}
        end

        {:ok, entry_with_days}
    end
  end

  #Atualiza uma única entrada no cronograma (aula)
  def update_schedule_entry_for_user(%User{}=user, entry_id, attrs) do
    case get_schedule_entry_for_user(user, entry_id) do
      {:ok, entry} ->
        #Verifica se estamos a atualizar uma série recorrente
        is_series_update = entry.is_recurring and Map.has_key?(attrs, "days_of_week")

        if is_series_update do
          #Atualização da série (recriar)
          Repo.transaction(fn ->
            #Remove todas as entradas do grupo antigo
            Repo.delete_all(from se in ScheduleEntry, where: se.recurrence_group_id == ^entry.recurrence_group_id)
            #Chama a função de criação para gerar as novas entradas (precisamos passar o student_id pois a função create espera)
            create_attrs = Map.put(attrs, "student_id", entry.student_id)
            #Reutilizamos a lógica de criação (que já gera novo group_id e lida com dias)
            case create_schedule_entries(user, entry.student_id, create_attrs) do
              {:ok, new_entries} -> List.first(new_entries)
              {:error, reason} -> Repo.rollback(reason)
            end
          end)
        else
          #atualização simples
          entry
          |> ScheduleEntry.changeset(attrs)
          |> Repo.update()
        end
    end
  end


  #Remove uma única entrada do cronograma(aula)
  def delete_schedule_entry_for_user(%User{}=user, entry_id) do
    case get_schedule_entry_for_user(user, entry_id) do
      {:ok, entry} ->
        Repo.delete(entry)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  #Retorna TODAS as entradas do cronograma para TODOS os alunos de um usuário,
  #com filtros opcionais
  def list_all_schedules_for_user(%User{}=user, filters \\ %{}) do

    week_start = Map.get(filters, "week_start")
    week_end = Map.get(filters, "week_end")

    if is_nil(week_start) or is_nil(week_end) do
      {:error, :data_range_required}
    end

    query =
      from g in Guardian,
      where: g.user_id == ^user.id,
      join: st in Student, on: st.id == g.student_id,
      join: se in ScheduleEntry, on: se.student_id == st.id,
      where:
        (se.specific_date >= ^week_start and se.specific_date <= ^week_end) or
        (
        not is_nil(se.day_of_week) and
        se.start_date <= ^week_end and
        (is_nil(se.end_date) or se.end_date >= ^week_start)
        ),
      join: s in Subject, on: s.id == se.subject_id,
      left_join: log in DailyLog, on: log.schedule_entry_id == se.id
                                            and log.log_date >= ^week_start
                                            and log.log_date <= ^week_end,
      left_join: u in User, on: u.id == se.assigned_guardian_id,
      order_by: [se.day_of_week, se.start_time],
      select: %{
        id: se.id,
        student_id: se.student_id,
        subject_id: se.subject_id,
        subject_name: s.name,
        student_name: st.name,
        assigned_guardian_id: se.assigned_guardian_id,
        responsible_avatar_id: u.avatar_id,
        day_of_week: se.day_of_week,
        start_time: se.start_time,
        end_time: se.end_time,
        status: log.status,
        log_id: log.id,
        is_recurring: not is_nil(se.day_of_week),
        specific_date: se.specific_date,
        excluded_dates: se.excluded_dates,
        recurrence_group_id: se.recurrence_group_id
      }

    query =
      if Map.get(filters, "only_mine", "false") == "true" do
        query |> where([g, st, se, s], se.assigned_guardian_id == ^user.id)
      else
        query
      end

    {:ok, Repo.all(query)}
  end


  #Cria uma exceção para uma aula recorrente
  #Adiciona a data da exceção à lista 'excluded_dates' da aula original
  #Cria uma nova aula única nessa data com os novos dados
  def create_schedule_exception(%User{} = user, original_entry_id, new_attrs) do
    #1. Busca a aula original
    case get_schedule_entry_for_user(user, original_entry_id) do
      {:ok, original_entry} ->
        exception_date = Date.from_iso8601!(new_attrs["exception_date"])

        Ecto.Multi.new()
        #Passo A: atualizar a original para ignorar esta data
        |> Ecto.Multi.update(:update_original, fn _ ->
          new_excluded_list = [exception_date | (original_entry.excluded_dates || [])]
          Ecto.Changeset.change(original_entry, excluded_dates: new_excluded_list)
        end)
        #Passo B: Criar a nova aula única (clone modificado)
        |> Ecto.Multi.insert(:insert_exception, fn _ ->
          #Prepara os atributos para a nova aula única
            exception_attrs = new_attrs
              |> Map.put("student_id", original_entry.student_id)
              |> Map.put("subject_id", original_entry.subject_id)
              |> Map.put("assigned_guardian_id", new_attrs["assigned_guardian_id"] || original_entry.assigned_guardian_id)
              |> Map.put("is_recurring", false)
              |> Map.put("specific_date", exception_date)
              |> Map.put("start_date", nil)
              |> Map.put("end_date", nil)
              |> Map.put("day_ok_week", nil)

            ScheduleEntry.changeset(%ScheduleEntry{}, exception_attrs)
          end)
        |> Repo.transaction()
        |> case do
          {:ok, %{insert_exception: new_entry}} -> {:ok, new_entry}
          {:error, _op, changeset, _} -> {:error, changeset}
        end

      {:error, :not_found} -> {:error, :not_found}
    end
  end

  #Exclui apenas UMA ocorrência de uma aula recorrente.
  #Adiciona a data especificada à lista de excluded_dates
  def exclude_schedule_occurrence(%User{}=user, entry_id, ocurrence_date_str) do
    #Busca a entrada e verifica a permissão
    case get_schedule_entry_for_user(user, entry_id) do
      {:ok, entry} ->
        #Verifica se é recorrente
        if entry.day_of_week != nil do
          #Converte a string para Date
          case Date.from_iso8601(ocurrence_date_str) do
            {:ok, date_to_exclude} ->
              #Adiciona a data à lista de exclusões (sem duplicados)
              current_excluded = entry.excluded_dates || []
              new_excluded = Enum.uniq([date_to_exclude | current_excluded])

              entry
              |> Ecto.Changeset.change(excluded_dates: new_excluded)
              |> Repo.update()

            {:error, _} ->
              {:error, :invalid_date_format}
          end
        else
          #Se não for recorrente, não faz sentido excluir ocorrência
          {:error, :not_recurring}
        end
      {:error, :not_found} ->
        {:error, :not_found}
    end
  end


  #Cria ou atualiza um registro diário para uma aula
  def create_or_update_daily_log(%User{}=user, schedule_entry_id, attrs) do
    #Verifica se o usuário tem permissão sobre a aula
    case get_schedule_entry_for_user(user, schedule_entry_id) do
      {:ok, entry} ->
        #Tenta encontrar um log existente para essa aula nessa data
        log_date = Date.from_iso8601!(attrs["log_date"])
        existing_log = Repo.get_by(DailyLog, schedule_entry_id: schedule_entry_id, log_date: log_date)

        if existing_log do
          #Atualizar log existente
          existing_log
          |> DailyLog.changeset(attrs)
          |> Repo.update()
        else
          #Criar novo log
          %DailyLog{}
          |> DailyLog.changeset(Map.put(attrs, "schedule_entry_id", schedule_entry_id))
          |> Repo.insert()
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end


  #Nova função de validação de conflito
  defp has_conflict?(student_id, start_time, end_time, scope) do
    query = from se in ScheduleEntry,
                where: se.student_id == ^student_id,
                #SObreposição de horário (válida para qualquer tipo de aula)
                where: se.start_time < ^end_time and se.end_time > ^start_time
    query = case scope do
      #Caso A: Estamos criando uma AULA ÚNICA numa data específica (target_date)
      {:single, target_date} ->
        day_of_week = Date.day_of_week(target_date)
        db_day_of_week = if day_of_week == 7, do: 0, else: day_of_week

        from se in query,
        where:
          #1. Conflito com outra aula única na mesma data
          (se.specific_date == ^target_date)
          or
          #2. Conflito com aula RECORRENTE ativa nesse dia da semana
          (
            se.day_of_week == ^db_day_of_week and
            se.start_date <= ^target_date and
            (is_nil(se.end_date) or se.end_date >= ^target_date)
          )
      #Caso B: Estamos criando uma AULA RECORRENTE (dias, start, end)
      {:recurring, days, new_start_date, new_end_date} ->
        target_end_date = new_end_date || ~D[9999-12-31]
        from se in query,
        where:
        #1. Conflito com AULA RECORRENTE que se sobreponha em datas e dias da semana
        (
          se.day_of_week in ^days and
          se.start_date <= ^target_end_date and
          (is_nil(se.end_date) or se.end_date >= ^new_start_date)
        )
        or
        #2. Conflito com AULA ÚNICA que caia num dos dias da semana E dentro do período
        (
          se.specific_date >= ^new_start_date and
          se.specific_date <= ^target_end_date and
          fragment("EXTRACT(DOW FROM ?)", se.specific_date) in ^days
        )
    end

    Repo.exists?(query)
  end

  #Função que executa a lógica de inserção
  defp perform_schedule_creation(student, attrs, false) do
    #Lógica de Aula ÚNICA
    clean_attrs = attrs
                    |> Map.put("student_id", student.id)
                    |> Map.put("is_recurring", false)
                    |> Map.put("start_date", nil)
                    |> Map.put("end_date", nil)
                    |> Map.put("days_of_week", nil)
                    |> Map.drop(["days_of_week"])

    %ScheduleEntry{}
      |> ScheduleEntry.changeset(clean_attrs)
      |> Ecto.Changeset.force_change(:start_date, nil)
      |> Ecto.Changeset.force_change(:end_date, nil)
      |> Ecto.Changeset.force_change(:day_of_week, nil)
      |> Repo.insert()
      |> case do
        {:ok, entry} -> {:ok, [entry]}
        {:error, changeset} -> {:error, changeset}
      end
  end


  defp perform_schedule_creation(student, attrs, true) do
    #Lógica de aula RECORRENTE
    days_of_week = Map.get(attrs, "days_of_week", [])

    #Gerar um ID único para este grupo
    group_id = Ecto.UUID.generate()

    base_attrs = attrs
                |> Map.drop(["days_of_week"])
                |> Map.put("student_id", student.id)
                |> Map.put("is_recurring", true)
                |> Map.put("specific_date", nil)
                |> Map.put("recurrence_group_id", group_id)
    base_attrs =
      if Map.get(base_attrs, "end_date") == "" do
        Map.put(base_attrs, "end_date", nil)
      else
        base_attrs
      end

    multi = Enum.reduce(days_of_week, Ecto.Multi.new(), fn day, multi ->
      aula_attrs = Map.put(base_attrs, "day_of_week", day)
      Ecto.Multi.insert(multi, "insert_day_#{day}", ScheduleEntry.changeset(%ScheduleEntry{}, aula_attrs))
    end)

    case Repo.transaction(multi) do
      {:ok, result_map} -> {:ok, Map.values(result_map)}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end



  #percorre todas as aulas agendadas para uma data específica.
  #Se a aula não tiver registro (daily_log), cria um com status :missed
  def mark_missed_activities_for_date(date \\ Date.add(Date.utc_today(), -1)) do
    #Por default, roda para 'ontem'
    #
    #Calcula o dia da semana
    day_of_week_elixir = Date.day_of_week(date)
    db_day_of_week = if day_of_week_elixir == 7, do: 0, else: day_of_week_elixir

    #Busca todas as entradas de cronograma que deveriam acontecer nesta data
    query =
      from se in ScheduleEntry,
      where:
        #Caso 1: evento único na data
        (se.specific_date == ^date)
        or
        #Caso 2: evento RECORRENTE ativo
        (
          se.day_of_week == ^db_day_of_week and
          se.start_date <= ^date and
          (is_nil(se.end_date) or se.end_date >= ^date)
        ),
        #Carrega os logs APENAS para esta data para verificarmos se já existe
        preload: [daily_logs: ^from(l in DailyLog, where: l.log_date == ^date)]

    entries = Repo.all(query)

    #Filtra e prepara os dados para inserção
    logs_to_insert =
      entries
      |> Enum.filter(fn entry ->
        #Filtro A: não deve ter log existente para hoje
        has_log? = Enum.any?(entry.daily_logs)
        #Filtro B: A data não deve estar na lista de exclusões (exceções)
        is_excluded? = entry.excluded_dates && date in entry.excluded_dates
        not has_log? and not is_excluded?
      end)
      |> Enum.map(fn entry ->
        #Prepara o mapa para inserção em massa
        %{
          schedule_entry_id: entry.id,
          log_date: date,
          status: :missed,
          notes: "Fechamento automático do dia.",
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second) #necessário para insert_all
        }
      end)

      #inserção em massa
      if length(logs_to_insert) > 0 do
        {count, _} = Repo.insert_all(DailyLog, logs_to_insert)
        {:ok, count}
      else
        {:ok, 0}
      end
  end

  #Calcula estatísticas de uma matéria: total de aulas planejadas (Até o fim do ano)
  #e o total de aulas concluídas
  def get_subject_stats(%Subject{}=subject) do
    #Carregar todas as entradas de cronograma (ScheduleEntries) desta matéria
    entries = Repo.all(from se in ScheduleEntry, where: se.subject_id == ^subject.id)

    #Contar aulas concluídas (baseado nos logs reais)
    completed_count = Repo.aggregate(
      from(l in DailyLog,
        join: se in ScheduleEntry, on: l.schedule_entry_id == se.id,
        where: se.subject_id == ^subject.id and l.status == :completed
      ),
      :count,
      :id
    ) || 0

    #Calcular Total Planejado (até o fim do ano atual)
    end_of_year = Date.new!(Date.utc_today().year(), 12, 31)
    total_planned = Enum.reduce(entries, 0, fn entry, acc ->
      acc + count_occurrences(entry, end_of_year)
    end)

    #Se o total planejado for 0 (ex. matéria nova), evita divisão por zero no progresso
    total_effective = max(total_planned, completed_count)

    progress = if total_effective > 0 do
      (completed_count / total_effective * 100) |> Float.round(1)
    else
      0.0
    end

    %{
      completed: completed_count,
      total: total_effective,
      progress: progress
    }

  end

  #Função auxiliar para contar ocorrências de UMA entrada
  defp count_occurrences(%ScheduleEntry{is_recurring: false}, _limit_date) do
    1 #aula única conta sempre como 1
  end
  defp count_occurrences(%ScheduleEntry{is_recurring: true} = entry, limit_date) do

    if is_nil(entry.start_date) do
      IO.warn("count_occurrences: Start date is missing")
      0
    else
       #Data de início efetiva
      start_date = entry.start_date

      #Data de fim efetiva: o menor entre (end_date da aula, fim do ano, hoje?)
      #nota: o cálculo de progresso geralmente considera "até hoje" ou "total do curso"
      #aqui vamos fazer "até o fim do corrente ano"
      actual_end_date =
        if is_nil(entry.end_date), do: limit_date, else: entry.end_date

      #Usa a menor data entre o fim definido e o limite( fim do ano)
      final_cutoff =
        if Date.compare(actual_end_date, limit_date) == :lt, do: actual_end_date, else: limit_date

      #Se a aula começa depois do corte, são 0 aulas
      if Date.compare(start_date, final_cutoff) == :gt do
        0
      else
        #Conta quantas vezes o da da semana ocorre no intervalo.
        target_day = entry.day_of_week
        Date.range(start_date, final_cutoff)
        |> Enum.count(fn date ->
          #Convert Date.day_of_week (1..7) para 0..6 se necessário
          elixir_day = Date.day_of_week(date)
          day_0_6 = if elixir_day == 7, do: 0, else: elixir_day
          is_day_match = day_0_6 == target_day
          excluded_list = entry.excluded_dates || []
          is_excluded = date in excluded_list
          is_day_match and not is_excluded
        end)
      end
    end

  end

  def get_daily_log_history_for_subject(subject_id) do
    (from l in DailyLog,
      join: se in ScheduleEntry, on: l.schedule_entry_id == se.id,
      where: se.subject_id == ^subject_id and l.status == :completed,
      order_by: [desc: l.log_date],
      select: %{
        id: l.id,
        log_date: l.log_date,
        notes: l.notes,
        status: l.status
      }
    )
    |> Repo.all()
  end


  #Lista os logs de um usuário para uma data específica.
  #GET /api/logs?date=YYY-MM-DD
  def list_daily_logs_for_date(%User{}=user, date) do
    query =
      from l in DailyLog,
      join: se in ScheduleEntry, on: l.schedule_entry_id == se.id,
      join: s in Student, on: se.student_id == s.id,
      join: g in Guardian, on: g.student_id == s.id,
      where: g.user_id == ^user.id and l.log_date == ^date,
      preload: [:log_attachments],
      select: l
    Repo.all(query)
  end

  #Gera uma URL pré-assinada para upload direto no S3
  def generate_attachment_presigned_url(filename, file_type) do
    bucket = Application.fetch_env!(:homeschooling, :s3_bucket)
    #Cria um caminho único: uploads/logs/UUID-nome.jpg
    key = "uploads/logs/#{Ecto.UUID.generate()}-#{filename}"

    #Gera a configuração
    config = ExAws.Config.new(:s3)

    #GEra URL para PUT (upload) válida por 15 minutos
    {:ok, url} =
      ExAws.S3.presigned_url(config, :put, bucket, key, [
        expires_in: 900,
        content_type: file_type
      ])
    public_url = "https://#{bucket}.s3.amazonaws.com/#{key}"
    {:ok, %{upload_url: url, public_url: public_url, key: key}}
  end

  #Registra o anexo do banco de dados após o upload
  def create_log_attachment(daily_log_id, attrs) do
    %LogAttachment{}
    |> LogAttachment.changeset(Map.put(attrs, "daily_log_id", daily_log_id))
    |> Repo.insert()
  end

  #retorna a lista de anexos para um log específico
  def list_log_attachments(log_id) do
    Repo.all(from a in LogAttachment, where: a.daily_log_id == ^log_id)
  end


  def get_user_dashboard_stats(%User{}=user) do
    #TOtal de alunos ativos
    active_students_count = Repo.aggregate(
      from(g in Guardian, where: g.user_id == ^user.id),
      :count,
      :id
    )

    #Progresso médio global
    #precisamos iterar sobre todos os alunos, todas as matérias, calcular o progresso de cada uma e fazer a média
    #busca todas as matérias de todos os alunos do usuário
    subjects = Repo.all(
      from s in Subject,
      join: st in Student, on: s.student_id == st.id,
      join: g in Guardian, on: g.student_id == st.id,
      where: g.user_id == ^user.id
    )

    total_progress_sum =
      subjects
      |> Enum.map(&get_subject_stats/1)
      |> Enum.map(fn stats -> stats.progress end)
      |> Enum.sum()

    average_progress =
      if (length(subjects)) >0 do
        (total_progress_sum / length(subjects)) |> Float.round(1)
      else
        0.0
      end

      %{
        active_students: active_students_count,
        average_progress: average_progress
      }
  end


end
