defmodule Japanese.Schemas.Anthropic.Response.Usage do
  @moduledoc """
  Ecto embedded schema and validator for LLM usage information returned by translation APIs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :input_tokens, :integer
    field :output_tokens, :integer
    field :service_tier, :string
    field :cache_creation_input_tokens, :integer
    field :cache_read_input_tokens, :integer
  end

  @type t :: %__MODULE__{}

  @doc """
  Returns a changeset for validating/parsing usage information from a map.
  Required: input_tokens, output_tokens, service_tier.
  Optional: cache_creation_input_tokens, cache_read_input_tokens.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :input_tokens,
      :output_tokens,
      :service_tier,
      :cache_creation_input_tokens,
      :cache_read_input_tokens
    ])
    |> validate_required([:input_tokens, :output_tokens, :service_tier])
  end

  @doc false
  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs), do: changeset(%__MODULE__{}, attrs)

  @doc """
  Parse a map of usage information (as returned by Anthropix/LLM) into a validated Usage struct.
  Returns {:ok, struct} or {:error, changeset}.
  """
  @spec parse_usage(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def parse_usage(attrs) do
    cs = changeset(attrs)
    if cs.valid?, do: {:ok, apply_changes(cs)}, else: {:error, cs}
  end
end
