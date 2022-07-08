defmodule EctoTenancyEnforcer.SourceCollector do
  @moduledoc false

  # Extracts a list of source modules from a query. This is used positionally by Ecto
  #  associations to tell what module an association is for.

  def collect_modules(query) do
    query
    |> collect_sources()
    |> associate_modules()
  end

  def collect_aliases(query, source_modules) do
    Map.new(query.aliases, fn {binding, ix} ->
      module = Enum.at(source_modules, ix) || throw(:err_index_missing_in_sources)
      {binding, module}
    end)
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
