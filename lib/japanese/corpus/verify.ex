defmodule Japanese.Corpus.Verify do
  @moduledoc """
  Read-only scan of the corpus, checking that every translation file still
  decodes into a shape the current reader understands.

  This module never writes anything: it opens files with `File.read/1` and
  decodes them with `Japanese.Translation.Json.decode_translation/1`. It is
  the logic behind `mix japanese.corpus.verify`, kept separate from the Mix
  task so the scan and its report shape can be exercised directly in tests
  without shelling out to `mix`.

  A story with no translation files, and a page that has not been translated
  yet, are not failures — there is nothing to decode. Only a translation file
  that exists and fails to decode, or decodes into a shape the reader cannot
  interpret (not an object, no `translation` list, or an entry that is not a
  map), counts as a failure. A per-entry field this reader does not know
  about is not a failure either — `Json.decode_translation/1` already
  tolerates it and logs it once; see its moduledoc.
  """

  alias Japanese.Corpus.StorageLayer
  alias Japanese.Translation.Json

  @type status :: :ok | {:error, String.t()}

  @type page_result :: %{
          story: String.t(),
          page: pos_integer(),
          file: String.t(),
          status: status()
        }

  @type report :: %{
          corpus_dir: String.t(),
          scanned: non_neg_integer(),
          ok: non_neg_integer(),
          pages: [page_result()],
          failures: [page_result()]
        }

  @doc """
  Scans every translation file reachable from `storage`'s working directory.

  Stories and pages are visited in a stable, numeric order (page `2` sorts
  before page `100`) so a report is reproducible and easy to skim across a
  corpus of a couple hundred chapters.
  """
  @spec run(StorageLayer.t()) :: report()
  def run(%StorageLayer{working_directory: corpus_dir} = storage) do
    pages =
      storage
      |> stories()
      |> Enum.flat_map(&story_pages(storage, &1))
      |> Enum.sort_by(&{&1.story, &1.page})

    failures = Enum.filter(pages, &match?({:error, _}, &1.status))

    %{
      corpus_dir: corpus_dir,
      scanned: length(pages),
      ok: length(pages) - length(failures),
      pages: pages,
      failures: failures
    }
  end

  @spec stories(StorageLayer.t()) :: [String.t()]
  defp stories(storage) do
    case StorageLayer.list_stories(storage) do
      {:ok, names} -> Enum.sort(names)
      {:error, _reason} -> []
    end
  end

  @spec story_pages(StorageLayer.t(), String.t()) :: [page_result()]
  defp story_pages(storage, story) do
    case StorageLayer.pair_files(storage, story) do
      {:ok, pairs} ->
        pairs
        |> Enum.reject(&is_nil(&1.translation))
        |> Enum.map(&page_result(storage, story, &1))

      {:error, _reason} ->
        []
    end
  end

  @spec page_result(StorageLayer.t(), String.t(), map()) :: page_result()
  defp page_result(%StorageLayer{working_directory: wd}, story, %{
         number: number,
         translation: file
       }) do
    path = Path.join([wd, story, file])

    %{story: story, page: number, file: file, status: decode(path)}
  end

  @spec decode(String.t()) :: status()
  defp decode(path) do
    case File.read(path) do
      {:ok, bytes} -> decode_bytes(bytes)
      {:error, reason} -> {:error, "could not read file: #{inspect(reason)}"}
    end
  end

  @spec decode_bytes(binary()) :: status()
  defp decode_bytes(bytes) do
    case Json.decode_translation(bytes) do
      {:ok, decoded} ->
        check_shape(decoded)

      {:error, %Jason.DecodeError{} = error} ->
        {:error, "malformed JSON: #{Exception.message(error)}"}

      {:error, reason} ->
        {:error, "malformed JSON: #{inspect(reason)}"}
    end
  end

  # A shape the current renderer can interpret: an object with a "translation"
  # list, and every entry in it a map (paragraph break, separator, pair, or an
  # entry carrying a field this reader has never heard of — all of those are
  # maps, and the renderer reads them with `Map.get/3`, so any map is fine).
  # Anything else — a scalar, a bare list, a "translation" that is not a
  # list, an entry that is not a map — is a shape the current reader cannot
  # interpret and would raise on when it tried to render it.
  @spec check_shape(term()) :: status()
  defp check_shape(%{translation: entries}) when is_list(entries) do
    case Enum.find_index(entries, &(not is_map(&1))) do
      nil ->
        :ok

      index ->
        {:error,
         "entry #{index + 1} is not a recognised shape: #{inspect(Enum.at(entries, index))}"}
    end
  end

  defp check_shape(_other), do: {:error, ~s(top level has no "translation" list)}
end
