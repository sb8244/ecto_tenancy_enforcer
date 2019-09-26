defmodule Tenancy.Repo.Migrations.CreatePeople do
  use Ecto.Migration

  def change do
    create table(:people) do
      add :name, :string
      add :tenant_id, :integer

      timestamps()
    end

    create index(:people, [:tenant_id])
  end
end
