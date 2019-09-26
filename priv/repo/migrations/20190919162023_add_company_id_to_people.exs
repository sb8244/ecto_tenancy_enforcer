defmodule Tenancy.Repo.Migrations.AddCompanyIdToPeople do
  use Ecto.Migration

  def change do
    alter table(:people) do
      add :company_id, :integer
    end
  end
end
