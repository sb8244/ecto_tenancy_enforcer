defmodule Tenancy.UUIDRecord do
  use Ecto.Schema

  schema "uuid_records" do
    field :name, :string
    field :uuid, Ecto.UUID

    timestamps()
  end
end
