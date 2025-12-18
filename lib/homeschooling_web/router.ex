defmodule HomeschoolingWeb.Router do
  use HomeschoolingWeb, :router

  pipeline :api do
    plug :accepts, ["json"]

    plug CORSPlug

  end

  pipeline :protected do
    plug HomeschoolingWeb.Auth.AuthPlug
  end

  scope "/api", HomeschoolingWeb do
    pipe_through :api
    post "/users/register", UserController, :register
    post "/users/login", UserController, :login
    post "users/request_password_reset", UserController, :request_password_reset
    post "/users/reset_password", UserController, :reset_password
    post "/users/verify", VerificationController, :verify
    post "/users/resend_verification", VerificationController, :resend
    post "/subscription/webhook", WebhookController, :handle

    options "/users/register", UserController, :register
    options "/users/login", UserController, :login
    options "users/request_password_reset", UserController, :request_password_reset
    options "/users/reset_password", UserController, :reset_password
    options "/users/verify", VerificationController, :verify
    options "/users/resend_verification", VerificationController, :resend
    options "/subscription/webhook", WebhookController, :handle
  end

  scope "/api", HomeschoolingWeb do
    pipe_through [:api, :protected]

    get "/me", UserController, :me
    get "/students", StudentController, :index
    get "/students/:id", StudentController, :show
    get "/students/:student_id/subjects", SubjectController, :index
    get "/subjects/:id", SubjectController, :show
    get "/students/:student_id/schedules", ScheduleController, :index
    get "/schedules/all", ScheduleController, :index_all
    get "/schedules/:id", ScheduleController, :show
    get "/logs", DailyLogController, :index
    get "/logs/upload_url", DailyLogController, :upload_url
    get "/logs/:id/attachments", DailyLogController, :index_attachments
    get "/dashboard/stats", DashboardController, :stats
    get "/assessments/upload_url", AssessmentController, :upload_url
    post "/students", StudentController, :create
    post "/students/:student_id/subjects", SubjectController, :create
    post "/subjects/:id/complete", SubjectController, :complete
    post "/subjects/:id/reactivate", SubjectController, :reactivate
    post "/schedules", ScheduleController, :create
    post "/schedules/:id/exception", ScheduleController, :create_exception
    post "/schedules/:id/logs", DailyLogController, :create
    post "/system/close_day", SystemController, :close_day
    post "/logs/:id/attachments", DailyLogController, :create_attachment
    post "/subjects/:subject_id/assessments", AssessmentController, :create
    post "/assessments/:id/attachments", AssessmentController, :create_attachment
    post "/subscriptions/checkout", SubscriptionController, :create_checkout_session
    post "/subscriptions/change", SubscriptionController, :change_plan
    post "/subscriptions/cancel-change", SubscriptionController, :cancel_change
    put "/students/:id", StudentController, :update
    put "/subjects/:id", SubjectController, :update
    put "/schedules/:id", ScheduleController, :update
    put "/assessments/:id", AssessmentController, :update
    delete "/students/:id", StudentController, :delete
    delete "/subjects/:id", SubjectController, :delete
    delete "/schedules/:id", ScheduleController, :delete
    delete "/schedules/:id/occurrence", ScheduleController, :delete_occurrence
    delete "/assessments/:id", AssessmentController, :delete


    options "/me", UserController, :me
    options "/students", StudentController, :create
    options "/students/:id", StudentController, :show
    options "/students/:id", StudentController, :update
    options "/students/:id", StudentController, :delete
    options "/students/:student_id/subjects", SubjectController, :index
    options "/students/:student_id/subjects", SubjectController, :create
    options "/subjects/:id", SubjectController, :show
    options "/subjects/:id", SubjectController, :update
    options "/subjects/:id/complete", SubjectController, :complete
    options "/subjects/:id/reactivate", SubjectController, :reactivate
    options "/subjects/:id", SubjectController, :delete
    options "/students/:student_id/schedules", ScheduleController, :index
    options "/schedules", ScheduleController, :create
    options "/schedules/:id", ScheduleController, :show
    options "/schedules/:id", ScheduleController, :update
    options "/schedules/:id", ScheduleController, :delete
    options "/schedules/all", ScheduleController, :index_all
    options "/schedules/:id/exception", ScheduleController, :create_exception
    options "/schedules/:id/occurrence", ScheduleController, :delete_occurrence
    options "/schedules/:id/logs", DailyLogController, :create
    options "/system/close_day", SystemController, :close_day
    options "/logs", DailyLogController, :index
    options "/logs/upload_url", DailyLogController, :upload_url
    options "/logs/:id/attachments", DailyLogController, :create_attachment
    options "/logs/:id/attachments", DailyLogController, :index_attachments
    options "/dashboard/stats", DashboardController, :stats
    options "/subjects/:subject_id/assessments", AssessmentController, :create
    options "/assessments/upload_url", AssessmentController, :upload_url
    options "/assessments/:id/attachments", AssessmentController, :create_attachment
    options "/assessments/:id", AssessmentController, :update
    options "/assessments/:id", AssessmentController, :delete
    options "/subscriptions/checkout", SubscriptionController, :create_checkout_session
    options "/subscriptions/change", SubscriptionController, :change_plan
    options "/subscriptions/cancel-change", SubscriptionController, :cancel_change

  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:homeschooling, :dev_routes) do

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
