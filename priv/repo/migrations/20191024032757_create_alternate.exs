defmodule Tenancy.Repo.Migrations.CreateAlternate do
  use Ecto.Migration

  def change do
    # Intended to be for alternate column name (team_id)
    create table(:alternates) do
      add :name, :string
      add :team_id, :integer
      add :company_id, :integer

      timestamps()
    end

    create index(:alternates, [:team_id])
  end
end
