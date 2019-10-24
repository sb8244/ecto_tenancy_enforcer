use Mix.Config

config :tenancy,
  ecto_repos: [Tenancy.Repo]

# Configure your database
config :tenancy, Tenancy.Repo,
  username: "postgres",
  password: "postgres",
  database: "tenancy_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Print only warnings and errors during test
config :logger, level: :warn
