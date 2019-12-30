# EctoTenancyEnforcer

EctoTenancyEnforcer provides a way to ensure that all queries made from your Elixir application, using Ecto, have
tenancy set. If a query is made that does not have tenancy set, you can handle that as an error or have it throw
an exception.

This library does not try to set tenancy on your queries. There are a lot more edge cases in that, and the
stakes are a lot higher. That makes this library opinionated that it is a good idea for you to always set
tenancy yourself.

Both `where` and `joins` are checked for tenancy, but more may be added over time if a valid use case arises.

## Benefits and Tradeoffs

_Pros_

- Strict tenancy enforcement in queries and join tables
- Tested across a fairly wide variety of queries
- Allows easier migration from vanilla Postgres to Citus Postgres

_Cons_

- Preloading is a bit finicky - requires use of preload subqueries for even basic preloads
- Lack of flexibility - the enforcement rules are not toggleable
- Some edge cases may be missed (Just make an issue)
- Does not get called for `insert_all` and `update_all`, due to how `Ecto.Repo` works

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

```elixir
test "valid tenancy is only condition" do
  valid = from c in Company, where: c.tenant_id == 1
  assert Repo.all(valid) |> length == 1
end

test "valid tenancy is only condition, filters pinned" do
  filters = [tenant_id: 1]
  valid = from c in Company, where: ^filters
  assert Repo.all(valid) |> length == 1
end

test "valid query with tenant id in dynamic" do
  dynamic_where = dynamic([c], c.tenant_id == 1)
  valid = from c in Company, where: ^dynamic_where
  assert Repo.all(valid) |> length == 1
end

test "valid, single join association has tenant_id included" do
  valid =
    from p in Person,
      join: c in Company,
      on: c.tenant_id == p.tenant_id,
      where: p.tenant_id == 1

  assert Repo.all(valid) |> length == 1

  valid =
    from p in Person,
      join: c in Company,
      on: c.tenant_id == p.tenant_id and c.id == p.company_id,
      where: p.tenant_id == 1

  assert Repo.all(valid) |> length == 1

  valid =
    from p in Person,
      join: c in assoc(p, :company),
      on: c.tenant_id == p.tenant_id,
      where: p.tenant_id == 1

  assert Repo.all(valid) |> length == 1
end
```

The following queries would not be allowed:

```elixir
test "no filters at all" do
  assert_raise(TenancyViolation, fn ->
    Repo.all(Company)
  end)
end

test "invalid query with multiple tenant id in list" do
  assert_raise(TenancyViolation, fn ->
    Repo.all(from c in Company, where: c.tenant_id in [1, 2])
  end)
end

test "invalid query with tenant id in fragment" do
  assert_raise(TenancyViolation, fn ->
    Repo.all(
      from c in Company,
        where: fragment("(?)", c.tenant_id) == 1
    )
  end)
end

test "invalid, all join associations must be equal on tenant_id" do
  assert_raise(TenancyViolation, fn ->
    Repo.all(from p in Person, join: c in Company, on: c.id == p.company_id, where: p.tenant_id == 1)
  end)

  assert_raise(TenancyViolation, fn ->
    Repo.all(
      from p in Person,
        join: c in assoc(p, :company),
        where: p.tenant_id == 1
    )
  end)
end
```

See [test/integration/prepare_test.exs](prepare_test.exs) for the complete set of tests for what is allowed and not allowed.

## Preloading

Unfortunately, I can not currently find a way to do preloading in a functional manner. This is one
situation where I think that the tenancy should come from the source objects. Due to this, you must always
use an `Ecto.Query` for preloading.

The following example demonstrates allowed preloading:

```elixir
test "Ecto.Query preload with tenant_id works", %{person: person} do
  p_q =
    from p in Person,
      where: p.tenant_id == 1

  valid =
    from c in Company,
      where: c.tenant_id == 1,
      preload: [people: ^p_q]

  assert [company] = Repo.all(valid)
  assert company.people == [person]
end
```

The following example demonstrates invalid preloading:

```elixir
test "preload from Ecto.Query without tenant_id is an error" do
  assert_raise(TenancyViolation, fn ->
    from(c in Company, where: c.tenant_id == 1, preload: [:people])
    |> Repo.all()
  end)
end
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## TODO

- CI (Travis)
