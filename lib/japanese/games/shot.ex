defmodule Japanese.Games.Shot do
  @moduledoc """
  One game screenshot that has been (or is being) turned into study text.

  Only the text is kept. The image itself stays on the Deck (`source_path`)
  and is fetched into memory just long enough to OCR and transcribe it, so
  the small disk on the server never fills up with screenshots.

  A shot is stored as one JSON file, `<corpus>/_games/<appid>/<id>.json`
  (see `Japanese.Games`). `sections` is kept exactly as
  `Japanese.Games.Transcript` produced it: a list of string-keyed maps, which
  is also the shape the LiveView renders.
  """

  @derive {Jason.Encoder,
           only: [
             :id,
             :deck,
             :appid,
             :game,
             :file,
             :source_path,
             :taken_at,
             :status,
             :error,
             :description,
             :kind,
             :pointer,
             :sections,
             :ocr_text,
             :model,
             :usage,
             :processed_at
           ]}

  @enforce_keys [:id, :deck, :appid, :file]
  defstruct [
    :id,
    :deck,
    :appid,
    :game,
    :file,
    :source_path,
    :taken_at,
    :error,
    :description,
    :kind,
    :pointer,
    :ocr_text,
    :model,
    :usage,
    :processed_at,
    status: :pending,
    sections: []
  ]

  @type status :: :pending | :processing | :done | :error

  @type t :: %__MODULE__{
          id: String.t(),
          deck: String.t(),
          appid: String.t(),
          game: String.t() | nil,
          file: String.t(),
          source_path: String.t() | nil,
          taken_at: String.t() | nil,
          status: status(),
          error: String.t() | nil,
          description: String.t() | nil,
          kind: String.t() | nil,
          pointer: String.t() | nil,
          sections: [map()],
          ocr_text: String.t() | nil,
          model: String.t() | nil,
          usage: map() | nil,
          processed_at: String.t() | nil
        }

  @statuses ~w(pending processing done error)

  @doc """
  Builds a new, not yet processed shot for a screenshot file on a Deck.

  `file` is the Steam screenshot file name (`20261001083845_1.jpg`); its
  timestamp becomes `taken_at` (Deck local time, as Steam wrote it).
  """
  @spec new(String.t(), String.t(), String.t(), keyword()) :: t()
  def new(deck, appid, file, opts \\ []) do
    %__MODULE__{
      id: id_for(deck, file),
      deck: deck,
      appid: appid,
      file: file,
      game: Keyword.get(opts, :game),
      source_path: Keyword.get(opts, :source_path),
      taken_at: taken_at(file)
    }
  end

  @doc """
  The shot id: the Deck name plus the screenshot's base name, so two Decks
  that happen to take a shot in the same second never collide.
  """
  @spec id_for(String.t(), String.t()) :: String.t()
  def id_for(deck, file), do: "#{deck}-#{Path.rootname(file)}"

  @doc """
  Parses Steam's `YYYYMMDDHHMMSS_N.jpg` name into `"YYYY-MM-DD HH:MM:SS"`, or
  nil for a file not named that way.
  """
  @spec taken_at(String.t()) :: String.t() | nil
  def taken_at(file) do
    case Regex.run(~r/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/, Path.basename(file)) do
      [_, y, mo, d, h, mi, s] -> "#{y}-#{mo}-#{d} #{h}:#{mi}:#{s}"
      _ -> nil
    end
  end

  @doc """
  Sort key, oldest first: the time the shot was taken, then the id (Steam's
  `_N` suffix orders shots taken in the same second).
  """
  @spec sort_key(t()) :: {String.t(), String.t()}
  def sort_key(%__MODULE__{taken_at: taken_at, id: id}), do: {taken_at || "", id}

  @doc """
  Rebuilds a shot from its decoded JSON file.
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"id" => id, "deck" => deck, "appid" => appid, "file" => file} = map)
      when is_binary(id) and is_binary(deck) and is_binary(appid) and is_binary(file) do
    {:ok,
     %__MODULE__{
       id: id,
       deck: deck,
       appid: appid,
       file: file,
       game: map["game"],
       source_path: map["source_path"],
       taken_at: map["taken_at"],
       status: decode_status(map["status"]),
       error: map["error"],
       description: map["description"],
       kind: map["kind"],
       pointer: map["pointer"],
       sections: List.wrap(map["sections"]),
       ocr_text: map["ocr_text"],
       model: map["model"],
       usage: map["usage"],
       processed_at: map["processed_at"]
     }}
  end

  def from_map(_), do: {:error, :invalid_shot}

  defp decode_status(status) when status in @statuses, do: String.to_existing_atom(status)
  defp decode_status(_), do: :error
end
