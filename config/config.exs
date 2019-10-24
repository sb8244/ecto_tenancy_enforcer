use Mix.Config

config :ecto_tenancy_enforcer,
  ecto_repos: [Tenancy.Repo]

# Configure your database
config :ecto_tenancy_enforcer, Tenancy.Repo,
  username: "postgres",
  password: "postgres",
  database: "tenancy_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Print only warnings and errors during test
config :logger, level: :warn
