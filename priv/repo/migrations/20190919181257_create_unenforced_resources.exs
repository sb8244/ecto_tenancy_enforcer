defmodule Tenancy.Repo.Migrations.CreateUnenforcedResources do
  use Ecto.Migration

  def change do
    create table(:unenforced_resources) do
      add :name, :string
      add :tenant_id, references(:tenants, on_delete: :nothing)

      timestamps()
    end

    create index(:unenforced_resources, [:tenant_id])
  end
end
