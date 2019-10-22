defmodule Tenancy.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants) do
      add :name, :string

      timestamps()
    end
  end
end
