defmodule EctoTenancyEnforcer do
  alias __MODULE__.{QueryVerifier, SchemaContext, TenancyViolation}

  def enforce!(query = %Ecto.Query{}, opts) do
    case enforce(query, opts) do
      ret = {:ok, _} ->
        ret

      {:error, message} ->
        raise TenancyViolation, message
    end
  end

  def enforce(query = %Ecto.Query{from: %{source: {_table, mod}}}, opts) do
    schema_context = Keyword.fetch!(opts, :enforced_schemas) |> SchemaContext.extract!()

    if SchemaContext.tenancy_enforced?(schema_context, mod) do
      QueryVerifier.verify_query(query, schema_context)
    else
      {:ok, :unenforced_schema}
    end
  end

  def enforce(%Ecto.Query{from: %{source: %{query: subquery}}}, enforced_schemas) do
    enforce(subquery, enforced_schemas)
  end
end
