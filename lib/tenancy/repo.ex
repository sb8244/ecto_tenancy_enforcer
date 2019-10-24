defmodule Tenancy.Repo do
  use Ecto.Repo,
    otp_app: :tenancy,
    adapter: Ecto.Adapters.Postgres

  @enforced_schemas [Tenancy.Company, {Tenancy.Person, :tenant_id}, {Tenancy.Alternate, :team_id}]

  def init(_type, config) do
    config = Keyword.merge(config, Application.get_env(:tenancy, Tenancy.Repo))
    {:ok, config}
  end

  def prepare_query(_operation, query, opts) do
    unless Keyword.get(opts, :tenancy_unchecked) do
      EctoTenancyEnforcer.enforce!(query, enforced_schemas: @enforced_schemas)
    end

    {query, opts}
  end
end
