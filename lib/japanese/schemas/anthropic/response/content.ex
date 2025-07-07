defmodule Japanese.Schemas.Anthropic.Response.Content do
  @moduledoc """
  Ecto embedded schema and validator for Anthropic LLM message content objects.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :type, :string
    field :text, :string
    # Add more fields here if Anthropic returns additional keys in content
  end

  @type t :: %__MODULE__{}

  @doc """
  Returns a changeset for validating/parsing a content object from a map.
  Required: type, text.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:type, :text])
    |> validate_required([:type, :text])
  end

  @doc false
  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs), do: changeset(%__MODULE__{}, attrs)

  @doc """
  Parse a map of content information (as returned by Anthropix/LLM) into a validated Content struct.
  Returns {:ok, struct} or {:error, changeset}.
  """
  @spec parse_content(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def parse_content(attrs) do
    cs = changeset(attrs)
    if cs.valid?, do: {:ok, apply_changes(cs)}, else: {:error, cs}
  end
end
