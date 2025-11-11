defmodule Japanese.Hume.Schemas.Voice do
  @moduledoc """
  Embedded schema for individual voice data from Hume API.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :name, :string
    field :provider, :string
  end

  def changeset(voice \\ %__MODULE__{}, attrs) do
    voice
    |> cast(attrs, [:id, :name, :provider])
    |> validate_required([:id, :name, :provider])
  end
end
