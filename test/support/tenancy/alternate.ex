defmodule Tenancy.Alternate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alternates" do
    field :name, :string
    # Not tenant_id
    field :team_id, :id
    belongs_to :company, Tenancy.Company

    timestamps()
  end

  @doc false
  def changeset(person, attrs) do
    person
    |> cast(attrs, [:name, :company_id])
    |> validate_required([:name])
  end
end
