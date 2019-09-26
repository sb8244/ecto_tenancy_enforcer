defmodule Tenancy.Person do
  use Ecto.Schema
  import Ecto.Changeset

  schema "people" do
    field :name, :string
    field :tenant_id, :id
    belongs_to :company, Tenancy.Company
    belongs_to :unenforced_resource, Tenancy.UnenforcedResource

    timestamps()
  end

  @doc false
  def changeset(person, attrs) do
    person
    |> cast(attrs, [:name, :company_id])
    |> validate_required([:name])
  end
end
