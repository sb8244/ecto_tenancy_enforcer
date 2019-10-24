defmodule Ecto.TestRepo do
  use Ecto.Repo, otp_app: :ecto_tenancy_enforcer, adapter: Ecto.TestAdapter

  def init(type, opts) do
    opts = [url: "ecto://user:pass@local/hello"] ++ opts
    opts[:parent] && send(opts[:parent], {__MODULE__, type, opts})
    {:ok, opts}
  end

  def prepare_query(_operation, query, opts) do
    EctoTenancyEnforcer.enforce!(query, enforced_schemas: [])
    {query, opts}
  end
end

Ecto.TestRepo.start_link()
