defmodule Japanese.Hume.Schemas.VoiceListResponse do
  @moduledoc """
  Embedded schema for Hume voice listing API response.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :page_number, :integer
    field :page_size, :integer
    field :total_pages, :integer
    embeds_many :voices_page, Japanese.Hume.Schemas.Voice
  end

  def changeset(response \\ %__MODULE__{}, attrs) do
    response
    |> cast(attrs, [:page_number, :page_size, :total_pages])
    |> validate_required([:page_number, :page_size, :total_pages])
    |> cast_embed(:voices_page)
  end
end
