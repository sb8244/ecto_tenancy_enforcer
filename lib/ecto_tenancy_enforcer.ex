defmodule EctoTenancyEnforcer do
  defmodule TenancyViolation do
    defexception message: nil
  end

  defmodule SchemaContext do
    def extract!(schemas) do
      %{
        enforced_schemas: extract_schemas(schemas),
        source_modules: :uninitialized
      }
    end

    def put(context, :source_modules, source_modules) do
      Map.put(context, :source_modules, source_modules)
    end

    def tenancy_enforced?(context, module) do
      module in enforced_modules(context)
    end

    def source_by_index(%{source_modules: sources}, ix) do
      Enum.at(sources, ix) || throw(:err_index_missing_in_sources)
    end

    def tenant_id_column_for_schema(%{enforced_schemas: schemas}, mod) do
      Map.fetch!(schemas, mod) |> Map.fetch!(:tenant_id_column)
    end

    defp enforced_modules(%{enforced_schemas: schemas}) do
      Map.keys(schemas)
    end

    # Extract into map of %{schema_module => %{tenant_id_column}}
    defp extract_schemas(schemas) do
      Enum.reduce(schemas, %{}, fn
        {schema, tenant_id_column}, map ->
          Map.put(map, schema, %{tenant_id_column: tenant_id_column})

        schema, map ->
          Map.put(map, schema, %{tenant_id_column: :tenant_id})
      end)
    end
  end

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
      verify_query(query, schema_context)
    else
      {:ok, :unenforced_schema}
    end
  end

  def enforce(%Ecto.Query{from: %{source: %{query: subquery}}}, enforced_schemas) do
    enforce(subquery, enforced_schemas)
  end

  defp verify_query(query, schema_context) do
    with source_modules <- SourceCollector.collect_modules(query),
         schema_context <- SchemaContext.put(schema_context, :source_modules, source_modules),
         {:ok, tenant_ids_in_wheres} <- enforce_where(query, schema_context),
         {:ok, tenant_ids_in_joins} <- enforce_joins(query, schema_context) do
      case Enum.uniq(tenant_ids_in_wheres ++ tenant_ids_in_joins) do
        [_] -> {:ok, :valid}
        _ -> {:error, "This query would run across multiple tenants: #{inspect(query)}"}
      end
    else
      e = {:error, _} ->
        e
    end
  end

  defp enforce_joins(query = %{joins: joins}, schema_context) do
    Enum.filter(joins, &join_requires_tenancy?(&1, schema_context))
    |> case do
      [] ->
        {:ok, []}

      joins ->
        each_join_result =
          Enum.reduce(joins, [], fn join = %{on: on_expr}, matched_values ->
            if join_requires_tenancy?(join, schema_context) do
              parse_expr(on_expr.expr, on_expr.params, matched_values, schema_context)
            else
              matched_values
            end
          end)

        if length(each_join_result) == length(joins) and Enum.all?(each_join_result, & &1) do
          {:ok, Enum.filter(each_join_result, &(&1 != :tenancy_equal))}
        else
          {:error, "This query has joins that don't include tenant_id: #{inspect(query)}"}
        end
    end
  end

  # Incorrect source module being extracted here. It is actually the association mod, the source is
  defp join_requires_tenancy?(%{source: {_table, mod}}, schema_context),
    do: SchemaContext.tenancy_enforced?(schema_context, mod)

  defp join_requires_tenancy?(%{assoc: {ix, name}}, schema_context) do
    case SchemaContext.source_by_index(schema_context, ix) do
      source_mod ->
        assoc_mod = source_mod.__schema__(:association, name).related
        Enum.all?([source_mod, assoc_mod], &SchemaContext.tenancy_enforced?(schema_context, &1))
    end
  end

  defp join_requires_tenancy?(_, _), do: true

  defp enforce_where(%{wheres: wheres}, schema_context) do
    matches = matched_values_from_where(wheres, [], schema_context)
    {:ok, Enum.uniq(matches)}
  end

  defp matched_values_from_where(
         [%{expr: expr, params: params} | exprs],
         matched_values,
         schema_context
       ) do
    matched_values = parse_expr(expr, params, matched_values, schema_context)
    matched_values_from_where(exprs, matched_values, schema_context)
  end

  defp matched_values_from_where([], matched_values, _schema_context),
    do: matched_values

  # This happens in joins
  defp parse_expr(
         {:==, [],
          [
            {{:., _, [{:&, _, [left_schema_ix]}, l_column]}, _, []},
            {{:., _, [{:&, _, [right_schema_ix]}, r_column]}, _, []}
          ]},
         _params,
         matched_values,
         schema_context
       ) do
    # A join is between two tables. We need to check that each table is joining on its appropriate
    # tenant_id_column, as they may be different
    case {
      SchemaContext.source_by_index(schema_context, left_schema_ix),
      SchemaContext.source_by_index(schema_context, right_schema_ix)
    } do
      {l_mod, r_mod} when not is_nil(l_mod) and not is_nil(r_mod) ->
        l_tenant_column_name = SchemaContext.tenant_id_column_for_schema(schema_context, l_mod)
        r_tenant_column_name = SchemaContext.tenant_id_column_for_schema(schema_context, r_mod)

        if l_column == l_tenant_column_name && r_column == r_tenant_column_name do
          [:tenancy_equal | matched_values]
        else
          matched_values
        end
    end
  end

  defp parse_expr({:==, _, [field, value]}, params, matched_values, schema_context) do
    with {query_mod, query_field} <- parse_field(field, schema_context),
         query_value <- parse_value(value, params),
         tenant_id_column <- SchemaContext.tenant_id_column_for_schema(schema_context, query_mod),
         true <- query_field == tenant_id_column and is_integer(query_value) do
      [query_value | matched_values]
    else
      _ ->
        matched_values
    end
  end

  defp parse_expr({:and, _, [expr1, expr2]}, params, matched_values, schema_context) do
    left = parse_expr(expr1, params, matched_values, schema_context)
    parse_expr(expr2, params, left, schema_context)
  end

  defp parse_expr({:in, _, [field, value]}, params, matched_values, schema_context) do
    {query_mod, query_field} = parse_field(field, schema_context)
    query_value = parse_value(value, params)
    tenant_id_column = SchemaContext.tenant_id_column_for_schema(schema_context, query_mod)

    case {query_field, query_value} do
      {^tenant_id_column, [item]} when is_integer(item) -> [item | matched_values]
      _ -> matched_values
    end
  end

  defp parse_expr(_, _, matched_values, _schema_context) do
    matched_values
  end

  defp parse_value(%Ecto.Query.Tagged{value: value}, _), do: value

  defp parse_value({:^, _, [ix]}, params) do
    case Enum.at(params || [], ix) do
      {value, _type} -> value
    end
  end

  defp parse_value(_, _), do: nil

  defp parse_field({{:., _, [{:&, _, [ix]}, field_name]}, _, []}, schema_context) do
    {SchemaContext.source_by_index(schema_context, ix), field_name}
  end

  # This value is not used by anything, so it's descriptive
  defp parse_field({:fragment, _, _}, _schema_context) do
    :tenancy_cannot_extract_from_fragment
  end
end

defmodule SourceCollector do
  @moduledoc """
  Extracts a list of source modules from a query. This is used positionally by Ecto
  associations to tell what module an association is for.
  """

  def collect_modules(query) do
    query
    |> collect_sources()
    |> associate_modules()
  end

  defp collect_sources(%{from: nil, joins: joins}) do
    ["query" | join_sources(joins)]
  end

  defp collect_sources(%{from: %{source: source}, joins: joins}) do
    [from_sources(source) | join_sources(joins)]
  end

  defp associate_modules([from | sources]) do
    Enum.reduce(sources, [from], fn source, acc ->
      normalized =
        case source do
          {var, association_name} ->
            source_mod = Enum.at(acc, var)
            source_mod.__schema__(:association, association_name).related

          source_mod ->
            source_mod
        end

      # Add to end to preserve `var` ordering
      acc ++ [normalized]
    end)
  end

  defp from_sources(%Ecto.SubQuery{query: query}), do: from_sources(query.from.source)
  defp from_sources({source, schema}), do: schema || source
  defp from_sources(nil), do: "query"

  defp join_sources(joins) do
    joins
    |> Enum.sort_by(& &1.ix)
    |> Enum.map(fn
      %Ecto.Query.JoinExpr{assoc: assoc = {_, _}} ->
        assoc

      %Ecto.Query.JoinExpr{source: {:fragment, _, _}} ->
        "fragment"

      %Ecto.Query.JoinExpr{source: %Ecto.Query{from: from}} ->
        from_sources(from.source)

      %Ecto.Query.JoinExpr{source: source} ->
        from_sources(source)
    end)
  end
end
