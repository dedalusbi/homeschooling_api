defmodule Homeschooling.Accounts do
  import Ecto.Query, warn: false
  alias Homeschooling.Repo
  alias Homeschooling.Mailer
  alias Homeschooling.Accounts.User
  alias Homeschooling.Accounts.PasswordResetToken
  alias Homeschooling.Accounts.EmailVerificationToken
  alias Homeschooling.Accounts.{Student, Guardian, Subject, SubjectCompletion}
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
    # Usando Ecto.Multi() para agrupar várias operações de base de dados que devem acontecer juntar (ou falhar juntas)
    Ecto.Multi.new()
    # 1. Tentando inserir o usuário utilizando o changeset de registro
    |> Ecto.Multi.insert(:user, %User{} |> User.registration_changeset(attrs))
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
    #Esta query faz um JOIN entre students e guardians para encontrar todos os students onde o user_id na tabela
    #guardians corresponde ao ID do usuário
    query =
      from s in Student,
      join: g in Guardian, on: g.student_id == s.id,
      where: g.user_id == ^user.id,
      select: s #Seleciona apenas os dados do aluno

    #Executa a query e retorna a lista de alunos
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

end
