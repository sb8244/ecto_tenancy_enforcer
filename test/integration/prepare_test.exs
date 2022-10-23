defmodule Integration.PrepareTest do
  use Tenancy.DataCase, async: true

  alias Tenancy.{Alternate, Company, UnenforcedResource, Person, UUIDRecord}
  alias Tenancy.Repo, as: Repo
  alias EctoTenancyEnforcer.TenancyViolation

  @uuid Ecto.UUID.generate()

  setup do
    assert {:ok, company} = Repo.insert(%Company{tenant_id: 1, name: "mine"})
    assert {:ok, company2} = Repo.insert(%Company{tenant_id: 2, name: "other tenant"})

    assert {:ok, person} = Repo.insert(%Person{tenant_id: 1, name: "Steve", company_id: company.id})

    assert {:ok, alternate} = Repo.insert(%Alternate{team_id: 1, name: "Steve", company_id: company.id})

    assert {:ok, uuid_id} = Repo.insert(%UUIDRecord{uuid: @uuid, name: "String ID"})

    {:ok, %{company: company, company2: company2, person: person, alternate: alternate, uuid_id: uuid_id}}
  end

  describe "Repo.all, single table" do
    test "no filters at all" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(Company)
      end)
    end

    test "valid tenancy is only condition" do
      valid = from c in Company, where: c.tenant_id == 1
      assert Repo.all(valid) |> length == 1
    end

    test "valid tenancy is only condition, filters pinned" do
      filters = [tenant_id: 1]
      valid = from c in Company, where: ^filters
      assert Repo.all(valid) |> length == 1
    end

    test "valid tenancy is only condition, pinned static" do
      valid = from c in Company, where: c.tenant_id == ^1
      assert Repo.all(valid) |> length == 1
    end

    test "valid tenancy is only condition, pinned to var" do
      val = 1
      valid = from c in Company, where: c.tenant_id == ^val
      assert Repo.all(valid) |> length == 1
    end

    test "valid tenancy with multiple conditions" do
      valid = from c in Company, where: c.tenant_id == 1 and c.id > 0
      assert Repo.all(valid) |> length == 1

      valid_reverse = from c in Company, where: c.id > 0 and c.tenant_id == ^1
      assert Repo.all(valid_reverse) |> length == 1
    end

    test "valid query with tenant id in single list" do
      valid = from c in Company, where: c.tenant_id in [1]
      assert Repo.all(valid) |> length == 1
    end

    test "valid query with tenant id in dynamic" do
      dynamic_where = dynamic([c], c.tenant_id == 1)
      valid = from c in Company, where: ^dynamic_where
      assert Repo.all(valid) |> length == 1
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

    test "invalid query, tenancy is not equal" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(
          from c in Company,
            where: c.tenant_id > 1
        )
      end)
    end

    test "invalid query, tenancy is pinned to multiple values" do
      assert_raise(TenancyViolation, fn ->
        a = 1
        b = 2

        Repo.all(
          from c in Company,
            where: c.tenant_id == ^a,
            where: c.tenant_id == ^b
        )
      end)
    end

    test "invalid query, 'or' condition sibling to tenant_id" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(
          from c in Company,
            where: c.tenant_id == 1 or c.id == 2
        )
      end)
    end

    test "valid, 'or' condition AND'd with tenant_id" do
      Repo.all(
        from c in Company,
          where: c.tenant_id == 1 and (c.id == 2 or c.id == 3)
      )
    end

    test "invalid, 'coalesce' criteria is ignored" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(
          from c in Company,
            where: coalesce(c.tenant_id, 1) == 1
        )
      end)
    end

    test "valid, 'coalesce' criteria is ignored" do
      Repo.all(
        from c in Company,
          where: c.tenant_id == 1 and coalesce(c.id, 1) == 2
      )
    end

    test "valid query with tenant id in named binding" do
      base = from c in Company, as: :company
      valid = from([company: c] in base, where: c.tenant_id == 1)
      assert Repo.all(valid) |> length == 1

      base = from c in Company, where: c.tenant_id == 1
      valid = from(c in base)
      assert Repo.all(valid) |> length == 1
    end

    test "valid query with tenant id in alias dynamic binding" do
      filter = dynamic(as(:company).tenant_id == 1)
      valid = from c in Company, as: :company, where: ^filter
      assert Repo.all(valid) |> length == 1

      filter = dynamic(as(:company).tenant_id in [1])
      valid = from c in Company, as: :company, where: ^filter
      assert Repo.all(valid) |> length == 1
    end

    test "invalid query with tenant id in alias dynamic binding" do
      filter = dynamic(as(:company).name == "nope")
      valid = from c in Company, as: :company, where: ^filter

      assert_raise(TenancyViolation, fn ->
        Repo.all(valid)
      end)
    end

    test "UUID fields are restricted" do
      # Basic valid tests
      valid = from c in UUIDRecord, where: c.uuid == ^@uuid
      assert Repo.all(valid) |> length == 1

      valid = from c in UUIDRecord, where: c.uuid == ^@uuid and c.name == "nope"
      assert Repo.all(valid) |> length == 0

      # Not included
      invalid = from c in UUIDRecord
      assert_raise(TenancyViolation, fn -> Repo.all(invalid) end)

      # Join is valid
      assert {:ok, _uuid_id2} = Repo.insert(%UUIDRecord{uuid: @uuid, name: "Same ID"})
      join = (
        from c in UUIDRecord,
        join: other in UUIDRecord,
        on: c.uuid == other.uuid,
        where: c.uuid == ^@uuid,
        distinct: c.id
      )
      assert Repo.all(join) |> length == 2

      # Join is invalid
      invalid_join = (
        from c in UUIDRecord,
        join: other in UUIDRecord,
        where: c.uuid == ^@uuid,
        distinct: c.id
      )
      assert_raise(TenancyViolation, fn -> Repo.all(invalid_join) end)
    end
  end

  describe "Repo.all, joined tables" do
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

    test "valid, no tenancy is required if the model isn't enforced" do
      valid =
        from p in Person,
          join: ur in UnenforcedResource,
          on: ur.id == p.company_id,
          where: p.tenant_id == 1

      assert Repo.all(valid) == []

      # I can see a case for this not being desired, but it's a fairly unusual query
      valid =
        from p in Person,
          join: ur in assoc(p, :unenforced_resource),
          join: p2 in assoc(ur, :people),
          where: p.tenant_id == 1

      assert Repo.all(valid) == []
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

    test "valid, single join association but source side has an alternate tenant id column name" do
      # Plain
      valid =
        from a in Alternate,
          join: c in Company,
          on: c.tenant_id == a.team_id,
          where: a.team_id == 1

      assert Repo.all(valid) |> length == 1

      # Array based
      valid =
        from a in Alternate,
          join: c in Company,
          on: c.tenant_id == a.team_id,
          where: a.team_id in [1]

      assert Repo.all(valid) |> length == 1

      # assoc
      valid =
        from a in Alternate,
          join: c in assoc(a, :company),
          on: a.team_id == c.tenant_id,
          where: a.team_id == 1

      assert Repo.all(valid) |> length == 1
    end

    test "valid, single join association but target side has an alternate tenant id column name" do
      # Plain
      valid =
        from c in Company,
          join: a in Alternate,
          on: c.tenant_id == a.team_id,
          where: c.tenant_id == 1

      assert Repo.all(valid) |> length == 1

      # Array based
      valid =
        from c in Company,
          join: a in Alternate,
          on: a.team_id == c.tenant_id,
          where: c.tenant_id in [1]

      assert Repo.all(valid) |> length == 1

      # assoc
      valid =
        from c in Company,
          join: a in assoc(c, :alternates),
          on: c.tenant_id == a.team_id,
          where: c.tenant_id == 1

      assert Repo.all(valid) |> length == 1
    end

    test "valid, single join association with a static tenant_id" do
      valid = from p in Person, join: c in Company, on: c.tenant_id == 1, where: p.tenant_id == 1

      assert Repo.all(valid) |> length == 1

      valid = from p in Person, join: c in Company, on: c.tenant_id == ^1, where: p.tenant_id == 1

      assert Repo.all(valid) |> length == 1
    end

    test "invalid, single join association with static tenant_id that isn't the same between joins or wheres" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(from p in Person, join: c in Company, on: c.tenant_id == ^1, where: p.tenant_id == 2)
      end)

      assert_raise(TenancyViolation, fn ->
        Repo.all(
          from p in Person,
            join: c in Company,
            on: c.tenant_id == ^1 and c.tenant_id == 2,
            where: p.tenant_id == 1
        )
      end)
    end

    test "valid, single join with single tenant id in list" do
      assert Repo.all(
               from p in Person,
                 join: c in Company,
                 on: c.tenant_id in [1],
                 where: p.tenant_id == 1
             )
             |> length() == 1
    end

    test "invalid, single join with different tenant id in list" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(from p in Person, join: c in Company, on: c.tenant_id in [2], where: p.tenant_id == 1)
      end)
    end

    test "invalid, single join with tenant id in list" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(from p in Person, join: c in Company, on: c.tenant_id in [1, 2], where: p.tenant_id == 1)
      end)
    end

    test "valid, multiple joins all include tenant_id" do
      valid =
        from p in Person,
          join: c in Company,
          on: c.tenant_id == p.tenant_id,
          join: c2 in Company,
          on: c2.tenant_id == p.tenant_id,
          where: p.tenant_id == 1

      assert Repo.all(valid) |> length == 1
    end

    test "invalid, multiple joins don't include tenant_id" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(
          from p in Person,
            join: c in Company,
            on: c.tenant_id == p.tenant_id,
            join: c2 in Company,
            on: c2.id == p.company_id,
            where: p.tenant_id == 1
        )
      end)
    end

    test "invalid, the query must be rooted to tenant_id" do
      assert_raise(TenancyViolation, fn ->
        Repo.all(from p in Person, join: c in Company, on: c.tenant_id == p.tenant_id)
      end)
    end
  end

  describe "Repo.get_by" do
    test "raises without tenant_id" do
      assert_raise(TenancyViolation, fn ->
        Repo.get_by(Company, id: 1)
      end)
    end

    test "works when tenant_id is the only thing present", %{company: company, company2: company2} do
      assert Repo.get_by(Company, tenant_id: company.tenant_id) == company
      assert Repo.get_by(Company, tenant_id: company2.tenant_id) == company2
    end

    test "works with multiple conditions", %{company: company = %{id: id, tenant_id: tenant_id}} do
      assert Repo.get_by(Company, tenant_id: 1, id: id) == company
      assert Repo.get_by(Company, id: id, tenant_id: 1) == company
      assert Repo.get_by(Company, id: id, tenant_id: tenant_id) == company
    end

    test "raises with multiple tenant_ids" do
      assert_raise(TenancyViolation, fn ->
        Repo.get_by(Company, tenant_id: 1, tenant_id: 2)
      end)
    end
  end

  describe "Repo.get" do
    test "raises for non-qualified queries" do
      assert_raise(TenancyViolation, fn ->
        Repo.get(Company, 1)
      end)
    end

    test "works for qualified queries", %{company: company} do
      valid = from c in Company, where: c.tenant_id == 1
      assert Repo.get(valid, company.id) == company
    end
  end

  describe "Repo.one" do
    test "raises for non-qualified queries", %{company: company} do
      assert_raise(TenancyViolation, fn ->
        Repo.one(from(c in Company))
      end)

      assert_raise(TenancyViolation, fn ->
        invalid = from c in Company, where: c.id == ^company.id
        Repo.one(invalid)
      end)
    end

    test "works for qualified queries", %{company: company} do
      valid = from c in Company, where: c.tenant_id == 1, where: c.id == ^company.id
      assert Repo.one(valid) == company
    end
  end

  describe "Repo.aggregate" do
    test "aggregates correctly with tenant_id set" do
      valid = from c in Company, where: c.tenant_id == 1
      assert Repo.aggregate(valid, :count, :id) == 1
    end

    test "aggregates correctly with distinct/limit/offset" do
      # sourced from repo_test "uses subqueries with distinct/limit/offset"
      valid = from c in Company, where: c.tenant_id == 1, limit: 1
      assert Repo.aggregate(valid, :count, :id) == 1
    end

    test "raises an error without tenant_id set" do
      assert_raise(TenancyViolation, fn ->
        invalid = from(c in Company)
        Repo.aggregate(invalid, :count, :id)
      end)
    end
  end

  describe "preload" do
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

    test "Ecto.Repo preload with tenant_id works", %{person: person} do
      p_q =
        from p in Person,
          where: p.tenant_id == 1

      valid =
        from c in Company,
          where: c.tenant_id == 1,
          preload: [people: ^p_q]

      assert [company] = Repo.all(valid)
      assert [company] = Repo.preload([company], people: p_q)
      assert company.people == [person]
    end

    @tag undesired: "This should be an error, but the queries are called separately"
    test "Ecto.Query preload with different tenant_id works" do
      p_q =
        from p in Person,
          where: p.tenant_id == 2

      valid =
        from c in Company,
          where: c.tenant_id == 1,
          preload: [people: ^p_q]

      assert [company] = Repo.all(valid)
      assert company.people == []
    end

    @tag undesired: "I'd like this query to be able to automatically extract tenancy"
    test "preload from Ecto.Query without tenant_id is an error" do
      assert_raise(TenancyViolation, fn ->
        from(c in Company, where: c.tenant_id == 1, preload: [:people])
        |> Repo.all()
      end)
    end

    @tag undesired: "I'd like this query to be able to automatically extract tenancy"
    test "preload from Ecto.Repo without tenant_id is an error" do
      assert_raise(TenancyViolation, fn ->
        from(c in Company, where: c.tenant_id == 1)
        |> Repo.all()
        |> Repo.preload([:people], tenant_id: 1)
      end)
    end
  end
end
