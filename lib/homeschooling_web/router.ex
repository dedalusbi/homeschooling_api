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

    options "/students", StudentController, :create
    options "/students/:id", StudentController, :show

  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:homeschooling, :dev_routes) do

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
