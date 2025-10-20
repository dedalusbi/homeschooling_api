defmodule HomeschoolingWeb.Router do
  use HomeschoolingWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", HomeschoolingWeb do
    pipe_through :api
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:homeschooling, :dev_routes) do

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
