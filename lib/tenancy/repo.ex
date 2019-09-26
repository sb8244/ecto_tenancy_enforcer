defmodule Tenancy.Repo do
  use Ecto.Repo,
    otp_app: :tenancy,
    adapter: Ecto.Adapters.Postgres
end

defmodule Tenancy.PrepareQueryRepo do
  use Ecto.Repo,
    otp_app: :tenancy,
    adapter: Ecto.Adapters.Postgres

  @enforced_schemas [Tenancy.Company, Tenancy.Person]

  def init(_type, config) do
    config = Keyword.merge(config, Application.get_env(:tenancy, Tenancy.Repo))
    {:ok, config}
  end

  def prepare_query(_operation, query, opts) do
    EctoTenancyEnforcer.enforce!(query, @enforced_schemas)
    {query, opts}
  end
end
