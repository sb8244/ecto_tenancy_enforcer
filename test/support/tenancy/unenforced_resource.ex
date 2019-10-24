defmodule Tenancy.UnenforcedResource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "unenforced_resources" do
    field :name, :string
    field :tenant_id, :id
    has_many :people, Tenancy.Person

    timestamps()
  end

  @doc false
  def changeset(unenforced_resource, attrs) do
    unenforced_resource
    |> cast(attrs, [:name, :tenant_id])
    |> validate_required([:name])
  end
end
