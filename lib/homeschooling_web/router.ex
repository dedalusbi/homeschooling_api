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

    options "/users/register", UserController, :register
    options "/users/login", UserController, :login
    options "users/request_password_reset", UserController, :request_password_reset
    options "/users/reset_password", UserController, :reset_password
    options "/users/verify", VerificationController, :verify
    options "/users/resend_verification", VerificationController, :resend
  end

  scope "/api", HomeschoolingWeb do
    pipe_through [:api, :protected]

    get "/me", UserController, :me
    post "/students", StudentController, :create
    get "/students", StudentController, :index
    get "/students/:id", StudentController, :show
    put "/students/:id", StudentController, :update
    delete "/students/:id", StudentController, :delete
    get "/students/:student_id/subjects", SubjectController, :index
    post "/students/:student_id/subjects", SubjectController, :create
    get "/subjects/:id", SubjectController, :show
    put "/subjects/:id", SubjectController, :update
    post "/subjects/:id/complete", SubjectController, :complete
    post "/subjects/:id/reactivate", SubjectController, :reactivate

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

  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:homeschooling, :dev_routes) do

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
