defmodule EctoTenancyEnforcer do
  alias __MODULE__.{QueryVerifier, SchemaContext, TenancyViolation}

  def enforce!(query = %Ecto.Query{}, config) do
    case enforce(query, config) do
      ret = {:ok, _} ->
        ret

      {:error, message} ->
        raise TenancyViolation, message
    end
  end

  def enforce(query = %Ecto.Query{from: %{source: {_table, mod}}}, config) do
    schema_context = Keyword.fetch!(config, :enforced_schemas) |> SchemaContext.extract!()

    if SchemaContext.tenancy_enforced?(schema_context, mod) do
      QueryVerifier.verify_query(query, schema_context, config: config)
    else
      {:ok, :unenforced_schema}
    end
  end

  def enforce(%Ecto.Query{from: %{source: %{query: subquery}}}, config) do
    enforce(subquery, config)
  end
end
