defmodule Tenancy.Repo do
  use Ecto.Repo,
    otp_app: :ecto_tenancy_enforcer,
    adapter: Ecto.Adapters.Postgres

  @enforced_schemas [
    Tenancy.Company,
    {Tenancy.Person, :tenant_id},
    {Tenancy.Alternate, :team_id},
    {Tenancy.UUIDRecord, :uuid}
  ]

  def init(_type, config) do
    config = Keyword.merge(config, Application.get_env(:ecto_tenancy_enforcer, Tenancy.Repo))
    {:ok, config}
  end

  def prepare_query(_operation, query, opts) do
    unless Keyword.get(opts, :tenancy_unchecked) do
      EctoTenancyEnforcer.enforce!(query, enforced_schemas: @enforced_schemas, always_allowed_tenant_ids: [1414, 1415])
    end

    {query, opts}
  end
end
