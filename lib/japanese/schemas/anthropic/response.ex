defmodule Japanese.Schemas.Anthropic.Response do
  @moduledoc """
  Ecto embedded schema and validator for Anthropic LLM response objects, including usage and content information.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Japanese.Schemas.Anthropic.Response.{Usage, Content}

  @primary_key false
  embedded_schema do
    field :id, :string
    field :model, :string
    field :role, :string
    field :stop_reason, :string
    field :stop_sequence, :string
    field :type, :string
    embeds_many :content, Content
    embeds_one :usage, Usage
  end

  @type t :: %__MODULE__{}

  @doc """
  Returns a changeset for validating/parsing an Anthropic response from a map.
  Required: id, model, role, type, content, usage.
  Optional: stop_reason, stop_sequence.
  """
  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :id,
      :model,
      :role,
      :stop_reason,
      :stop_sequence,
      :type
    ])
    |> cast_embed(:content, required: true)
    |> cast_embed(:usage, required: true)
    |> validate_required([:id, :model, :role, :type])
  end

  @doc """
  Parse a map of response information (as returned by Anthropix/LLM) into a validated Response struct.
  Returns {:ok, struct} or {:error, changeset}.
  """
  @spec parse_response(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def parse_response(attrs) do
    cs = changeset(attrs)
    if cs.valid?, do: {:ok, apply_changes(cs)}, else: {:error, cs}
  end
end
