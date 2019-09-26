defmodule EctoTenancyEnforcer do
  defmodule TenancyViolation do
    defexception message: nil
  end

  def enforce!(query = %{from: %{source: {_table, mod}}}, enforced_schemas) do
    if mod in enforced_schemas do
      source_modules = SourceCollector.collect_modules(query)

      {:ok, tenant_ids_in_wheres} = enforce_where!(query)
      {:ok, tenant_ids_in_joins} = enforce_joins!(query, enforced_schemas, source_modules)

      case Enum.uniq(tenant_ids_in_wheres ++ tenant_ids_in_joins) do
        [_] -> true
        _ -> raise TenancyViolation, "This query would run across multiple tenants: #{inspect query}"
      end

      true
    else
      :unenforced_schema
    end
  end

  defp enforce_joins!(query = %{joins: joins}, enforced_schemas, source_modules) do
    Enum.filter(joins, & join_requires_tenancy?(&1, enforced_schemas, source_modules))
    |> case do
      [] ->
        {:ok, []}

      joins ->
        each_join_result =
          Enum.reduce(joins, [], fn join = %{on: on_expr}, matched_values ->
            if join_requires_tenancy?(join, enforced_schemas, source_modules) do
              parse_expr(on_expr.expr, on_expr.params, matched_values)
            else
              matched_values
            end
          end)

        if length(each_join_result) == length(joins) and Enum.all?(each_join_result, & &1) do
          {:ok, Enum.filter(each_join_result, & &1 != :tenancy_equal)}
        else
          raise TenancyViolation, "This query has joins that don't include tenant_id: #{inspect query}"
        end
    end
  end

  defp join_requires_tenancy?(%{source: {_table, mod}}, enforced_schemas, _source_mods), do: mod in enforced_schemas
  defp join_requires_tenancy?(%{assoc: {ix, name}}, enforced_schemas, source_mods) do
    case Enum.at(source_mods, ix) do
      source_mod when not is_nil(source_mod) ->
        assoc_mod = source_mod.__schema__(:association, name).related

        Enum.all?([source_mod, assoc_mod], & Enum.member?(enforced_schemas, &1))
    end
  end
  defp join_requires_tenancy?(_, _, _), do: true

  defp enforce_where!(%{wheres: wheres}) do
    matches = matched_values_from_where(wheres, [])
    {:ok, Enum.uniq(matches)}
  end

  defp matched_values_from_where([%{expr: expr, params: params} | exprs], matched_values) do
    matched_values = parse_expr(expr, params, matched_values)
    matched_values_from_where(exprs, matched_values)
  end

  defp matched_values_from_where([], matched_values), do: matched_values

  # This happens in joins
  defp parse_expr({:==, [], [
    {{:., [], [{:&, [], [_]}, left_column]}, [], []},
    {{:., [], [{:&, [], [_]}, right_column]}, [], []}
  ]}, _params, matched_values) do
    if left_column == :tenant_id && right_column == :tenant_id do
      [:tenancy_equal | matched_values]
    else
      matched_values
    end
  end

  defp parse_expr({:==, _, [field, value]}, params, matched_values) do
    query_field = parse_field(field)
    query_value = parse_value(value, params)

    if query_field == :tenant_id and is_integer(query_value) do
      [query_value | matched_values]
    else
      matched_values
    end
  end

  defp parse_expr({:and, [], [expr1, expr2]}, params, matched_values) do
    left = parse_expr(expr1, params, matched_values)
    parse_expr(expr2, params, left)
  end

  defp parse_expr({:in, [], [field, value]}, params, matched_values) do
    query_field = parse_field(field)
    query_value = parse_value(value, params)

    case {query_field, query_value} do
      {:tenant_id, [item]} when is_integer(item) -> [item | matched_values]
      _ -> matched_values
    end
  end

  defp parse_expr(_, _, matched_values) do
    matched_values
  end

  defp parse_value(%Ecto.Query.Tagged{value: value}, _), do: value

  defp parse_value({:^, [], [ix]}, params) do
    case Enum.at(params || [], ix) do
      {value, _type} -> value
    end
  end

  defp parse_field({{:., [], [{:&, [], [_ix]}, field_name]}, [], []}) do
    field_name
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
