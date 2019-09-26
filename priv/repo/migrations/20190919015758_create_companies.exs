defmodule Tenancy.Repo.Migrations.CreateCompanies do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name, :string
      add :tenant_id, :integer

      timestamps()
    end

    create index(:companies, [:tenant_id])
  end
end
