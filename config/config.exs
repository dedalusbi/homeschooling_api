# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :homeschooling,
  ecto_repos: [Homeschooling.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :homeschooling, HomeschoolingWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: HomeschoolingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Homeschooling.PubSub,
  live_view: [signing_salt: "+1IleQWw"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :homeschooling, Homeschooling.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

#Configuração para os limites de alunos por assinatura
config :homeschooling, :subscription_limits, %{
  essential: 1,
  family: 3,
  educator: 999_999

}

config :ex_aws,
  #access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  #secret_access_key: System.get_env("AWS_SECRET_ACESS_KEY")
  access_key_id: "AKIAYS2NSFDZRWMOQ2HZ",
  secret_access_key: "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",
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "https://",
  host: "s3.amazonaws.com",
  region: "us-east-1"

config :homeschooling, :s3_bucket, "educasa-uploads"

config :mint,
  transport_options: [
    {:debug, {:output, :standard_io}},
    {:log_level, :debug}
  ]

config :stripity_stripe,
  api_key: "sk_test_51SZZbLJQV5vJKLkqZZZd2iUdmPm8IFCbQ6dGNBBSgMUnFYfEb6hAtjey2OT6VDsst1wGJkz4HE7ddQpFs7OtTRIr002ouLIb2r",
  signing_secret: " whsec_9bed91c997649e891dfb6d2431b78fcd6656e0cf676da46a3022d24334439da0"
