defmodule Japanese.Games do
  @moduledoc """
  Game screenshots turned into study text.

  A Steam Deck takes a screenshot; `Japanese.Games.DeckWatcher` notices it
  over SSH, `Japanese.Games.Processor` fetches the image into memory, OCRs it
  with Google Vision and has Claude turn it into sections of Japanese /
  hiragana / English (`Japanese.Games.Pipeline`). Only the resulting text is
  stored, one JSON file per shot under `<corpus>/_games/<appid>/`. That
  directory is deliberately skipped by the story listing (see
  `Japanese.Corpus.StorageLayer.games_directory/0`).

  Changes are broadcast on the `"games"` PubSub topic (see `subscribe/0`):

    * `{:shot_added, shot}` — a new screenshot was found (status `:pending`)
    * `{:shot_updated, shot}` — a shot finished, failed or is being re-run
    * `{:deck_status, status}` — the watcher connected or lost the Deck
  """

  require Logger

  alias Japanese.Corpus.StorageLayer
  alias Japanese.Games.Shot

  @topic "games"

  @doc """
  Directory that holds all game shot records.

  Defaults to `<CORPUS_DIR>/_games`; override with
  `config :japanese, Japanese.Games, dir: "..."` (used by tests).
  """
  @spec dir() :: String.t()
  def dir do
    case Application.get_env(:japanese, __MODULE__, [])[:dir] do
      nil -> Path.join(StorageLayer.new().working_directory, StorageLayer.games_directory())
      dir -> dir
    end
  end

  @doc """
  All shots, newest first.
  """
  @spec list_shots() :: [Shot.t()]
  def list_shots do
    Path.join([dir(), "*", "*.json"])
    |> Path.wildcard()
    |> Enum.flat_map(fn path ->
      case read_file(path) do
        {:ok, shot} -> [shot]
        {:error, _} -> []
      end
    end)
    |> Enum.sort_by(&Shot.sort_key/1, :desc)
  end

  @doc """
  The newest shot, or nil if there are none.
  """
  @spec latest_shot() :: Shot.t() | nil
  def latest_shot, do: List.first(list_shots())

  @doc """
  Fetches a shot by id.
  """
  @spec get_shot(String.t()) :: {:ok, Shot.t()} | {:error, :not_found | term()}
  def get_shot(id) when is_binary(id) do
    if safe_name?(id) do
      case Path.wildcard(Path.join([dir(), "*", id <> ".json"])) do
        [path | _] -> read_file(path)
        [] -> {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  True if a record already exists for this shot id.
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(id), do: match?({:ok, _}, get_shot(id))

  @doc """
  Writes a shot record (atomically: temp file, then rename).
  """
  @spec save_shot(Shot.t()) :: {:ok, Shot.t()} | {:error, term()}
  def save_shot(%Shot{appid: appid, id: id} = shot) do
    if safe_name?(appid) and safe_name?(id) do
      game_dir = Path.join(dir(), appid)
      path = Path.join(game_dir, id <> ".json")
      tmp = path <> ".tmp"

      with :ok <- File.mkdir_p(game_dir),
           {:ok, json} <- Jason.encode(shot, pretty: true),
           :ok <- File.write(tmp, json),
           :ok <- File.rename(tmp, path) do
        {:ok, shot}
      end
    else
      {:error, :invalid_name}
    end
  end

  @doc """
  The game name already recorded for an appid on some earlier shot, if any.
  Saves asking the Deck again for every screenshot of the same game.
  """
  @spec known_game_name(String.t()) :: String.t() | nil
  def known_game_name(appid) do
    Path.join([dir(), appid, "*.json"])
    |> Path.wildcard()
    |> Enum.find_value(fn path ->
      case read_file(path) do
        {:ok, %Shot{game: game}} when is_binary(game) -> game
        _ -> nil
      end
    end)
  end

  @doc """
  Subscribes the caller to shot and Deck status updates.
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Japanese.PubSub, @topic)

  @doc false
  @spec broadcast(term()) :: :ok
  def broadcast(message) do
    Phoenix.PubSub.broadcast(Japanese.PubSub, @topic, message)
  end

  @doc """
  The Deck watcher's current status, for display. Never raises: if the
  watcher isn't running (disabled, or in tests) the status is `:disabled`.
  """
  @spec deck_status() :: Japanese.Games.DeckWatcher.status()
  def deck_status do
    Japanese.Games.DeckWatcher.status()
  catch
    :exit, _ -> :disabled
  end

  defp read_file(path) do
    with {:ok, body} <- File.read(path),
         {:ok, map} <- Jason.decode(body),
         {:ok, shot} <- Shot.from_map(map) do
      {:ok, shot}
    else
      {:error, reason} = error ->
        Logger.warning("Skipping unreadable game shot #{path}: #{inspect(reason)}")
        error
    end
  end

  # Ids and appids become file names; refuse anything that could step out of
  # the games directory.
  defp safe_name?(name), do: is_binary(name) and name =~ ~r/^[A-Za-z0-9][A-Za-z0-9_.-]*$/
end
