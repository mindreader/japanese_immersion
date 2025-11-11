defmodule Japanese.Hume.Schemas.TtsResponse do
  @moduledoc """
  Embedded schema for Hume TTS response data with validated file paths.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :request_id, :string
    embeds_many :generations, __MODULE__.Generation
  end

  defmodule Generation do
    @moduledoc """
    Individual generation within a TTS response.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :audio_file_path, :string
      embeds_many :snippets, Japanese.Hume.Schemas.TtsResponse.Snippet
    end

    def changeset(generation \\ %__MODULE__{}, attrs) do
      generation
      |> cast(attrs, [:audio_file_path])
      |> validate_required([:audio_file_path])
      |> cast_embed(:snippets)
    end
  end

  defmodule Snippet do
    @moduledoc """
    Audio snippet within a generation.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :id, :string
      field :generation_id, :string
      field :audio_file_path, :string
    end

    def changeset(snippet \\ %__MODULE__{}, attrs) do
      snippet
      |> cast(attrs, [:id, :generation_id, :audio_file_path])
      |> validate_required([:audio_file_path])
    end
  end

  def changeset(response \\ %__MODULE__{}, attrs) do
    response
    |> cast(attrs, [:request_id])
    |> validate_required([:request_id])
    |> cast_embed(:generations)
  end
end
