defmodule Tenancy.Repo.Migrations.CreateStringId do
  use Ecto.Migration

  def change do
    # Intended to be for alternate column name (team_id)
    create table(:uuid_records) do
      add :name, :string
      add :uuid, :binary_id

      timestamps()
    end

    create index(:uuid_records, [:uuid])
  end
end
