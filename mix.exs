defmodule Tenancy.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_tenancy_enforcer,
      version: "0.0.1",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),

      name: "Ecto Tenancy Enforcer",
      description: "Provides a way to ensure that all queries made from your Elixir application, using Ecto, have tenancy set",
      package: package(),
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto, "~> 3.2"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp package do
    [
      maintainers: ["Stephen Bussey"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sb8244/ecto_tenancy_enforcer"},
      files:
        ~w(.formatter.exs mix.exs README.md CHANGELOG.md lib)
    ]
  end
end
