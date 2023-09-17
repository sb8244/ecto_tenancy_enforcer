defmodule EctoTenancyEnforcer.SchemaContext do
  @moduledoc false

  # Helpers for exchanging information
  #  enforced_schemas: List of modules that are enforced. Options can be provided as well
  #  source_modules: extracted Ecto.Query representation of source module to index mapping

  def extract!(schemas) do
    %{
      enforced_schemas: extract_schemas(schemas),
      source_modules: :uninitialized,
      source_aliases: %{}
    }
  end

  def put(context, :source_modules, source_modules) do
    Map.put(context, :source_modules, source_modules)
  end

  def put(context, :source_aliases, aliases) do
    Map.put(context, :source_aliases, aliases)
  end

  def tenancy_enforced?(context, module) do
    module in enforced_modules(context)
  end

  def source_by_index(%{source_modules: sources}, ix) do
    Enum.at(sources, ix) || throw(:err_index_missing_in_sources)
  end

  def source_by_alias(%{source_aliases: aliases}, named_binding) do
    Map.get(aliases, named_binding) || throw(:err_named_binding_missing_in_sources)
  end

  def tenant_id_column_for_schema(%{enforced_schemas: schemas}, mod) do
    Map.fetch!(schemas, mod) |> Map.fetch!(:tenant_id_column)
  end

  def maybe_tenant_id_column_for_schema(%{enforced_schemas: schemas}, mod) do
    case Map.get(schemas, mod) do
      nil -> nil
      mod -> Map.fetch!(mod, :tenant_id_column)
    end
  end

  # private

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
