# EctoTenancyEnforcer

EctoTenancyEnforcer provides a way to ensure that all queries made from your Elixir application, using Ecto, have tenancy set. If a query is made that
does not have tenancy set, you can handle that as an error or have it throw an exception.

This library does not try to set tenancy on your queries. There are a lot more edge cases in that, and the stakes are a lot higher. That makes
this library opinionated that it is a good idea for you to always set tenancy yourself.

Both `where` and `joins` are checked for tenancy, but more may be added over time if a valid use case arises.

## Configuration

The `EctoTenancyEnforcer.enforce/2` (and !) functions are to be used in the `Ecto.Repo.prepare_query/3` callback. This callback
provides the entire `Ecto.Query` struct that is then introspected.

If you want to handle the tenancy error yourself (or log it), then use the non-bang version. If you want it to error out and
not execute the query, then use the bang version.

The `enforced_schemas` key is where you configure your schemas that are tenant'd. The default column is assumed to be `tenant_id`,
but you can customize it. To customize it, use the format `{MySchema, :my_tenant_column}` like in the following example.

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  @enforced_schemas [Company, {Person, :tenant_id}, {Alternate, :team_id}]

  def init(_type, config) do
    config = Keyword.merge(config, Application.get_env(:my_app, MyApp.Repo))
    {:ok, config}
  end

  def prepare_query(_operation, query, opts) do
    unless Keyword.get(opts, :tenancy_unchecked) do
      EctoTenancyEnforcer.enforce!(query, enforced_schemas: @enforced_schemas)
    end

    {query, opts}
  end
end
```

## Query Examples

The following queries are all allowed (assuming `Person` and `Company` are enforced schemas):
//TODO

The following queries would not be allowed:
//TODO

## Preloading

Unfortunately, I can not currently find a way to do preloading in a functional manner. This is one situation where I think that the tenancy should
come from the source objects. Due to this, you must always use an `Ecto.Query` for preloading.

The following examples demonstrate allowed and not-allowed preloading:

// TODO

## Contributing

// TODO
