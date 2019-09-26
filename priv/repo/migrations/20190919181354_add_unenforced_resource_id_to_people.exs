defmodule Tenancy.Repo.Migrations.AddUnenforcedResourceIdToPeople do
  use Ecto.Migration

  def change do
    alter table(:people) do
      add :unenforced_resource_id, :integer
    end
  end
end
