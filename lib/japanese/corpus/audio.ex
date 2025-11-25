defmodule Japanese.Corpus.Audio do
  @moduledoc """
  Functions for generating and managing audio files for corpus pages.
  """

  alias Japanese.Corpus.Page
  alias Japanese.Corpus.StorageLayer
  alias Japanese.Corpus.Story
  alias Japanese.Fal
  alias Japanese.Utils

  @valid_voices [:jf_alpha, :jf_gongitsune, :jf_nezumi, :jf_tebukuro, :jm_kumo]

  @doc """
  Generate audio files for all snippets in a page.

  Takes a page, extracts Japanese statements, and generates TTS audio for each one.
  By default, skips snippets that already have audio files generated.

  ## Parameters
  - `page` - A Page struct
  - `voice` - Voice atom (e.g., :jf_alpha, :jf_gongitsune, :jf_nezumi, :jf_tebukuro, :jm_kumo)
  - `opts` - Optional keyword list:
    - `:skip_existing` - Skip snippets with existing audio (default: true)
    - `:limit` - Maximum number of snippets to process (for testing)
    - Other opts are passed to Japanese.Fal.tts/4 (e.g., :speed)

  ## Returns
  {:ok, results} where results is a list of maps:
  %{
    japanese: "original Japanese text",
    file_path: "/path/to/audio/voice_hash.mp3"
  }

  ## Examples
      iex> page = %Page{story: "story1", number: 1}
      iex> Japanese.Corpus.Audio.generate_for_page(page, :jf_alpha)
      {:ok, [%{japanese: "...", file_path: "..."}]}

      iex> Japanese.Corpus.Audio.generate_for_page(page, :jf_alpha, limit: 3)
      {:ok, [%{japanese: "...", file_path: "..."}]}  # Only first 3 snippets
  """
  @spec generate_for_page(Page.t(), atom(), keyword()) ::
          {:ok, [%{japanese: String.t(), file_path: String.t()}]} | {:error, term()}
  def generate_for_page(%Page{story: story} = page, voice, opts \\ []) do
    skip_existing = Keyword.get(opts, :skip_existing, true)
    limit = Keyword.get(opts, :limit)
    storage = StorageLayer.new()

    with {:ok, statements} <- Utils.parse_japanese_statements(page) do
      statements_to_process = if limit, do: Enum.take(statements, limit), else: statements

      results =
        Enum.map(statements_to_process, fn statement ->
          hash = hash_text(statement.japanese)
          base_filename = "#{voice}_#{hash}"
          audio_dir = Path.join([storage.working_directory, story, "audio"])
          audio_pattern = Path.join(audio_dir, "#{base_filename}.*")

          existing_file =
            if skip_existing do
              Path.wildcard(audio_pattern) |> List.first()
            end

          if existing_file do
            %{japanese: statement.japanese, file_path: existing_file}
          else
            {:ok, file_path} = Fal.tts(voice, statement.japanese_tts, story, base_filename, opts)
            %{japanese: statement.japanese, file_path: file_path}
          end
        end)

      {:ok, results}
    end
  end

  @doc """
  Generate audio files for all pages in a story.

  Takes a story, and generates TTS audio for all snippets across all pages.
  By default, skips snippets that already have audio files generated.

  ## Parameters
  - `story` - A Story struct
  - `voice` - Voice atom (e.g., :jf_alpha, :jf_gongitsune, :jf_nezumi, :jf_tebukuro, :jm_kumo)
  - `opts` - Optional keyword list:
    - `:skip_existing` - Skip snippets with existing audio (default: true)
    - `:limit` - Maximum number of snippets to process per page (for testing)
    - Other opts are passed to Japanese.Fal.tts/4 (e.g., :speed)

  ## Returns
  {:ok, results} where results is a list of all audio files generated across all pages
  {:error, reason} if generation fails for all pages

  ## Examples
      iex> story = %Story{name: "story1"}
      iex> Japanese.Corpus.Audio.generate_for_story(story, :jf_alpha)
      {:ok, [%{japanese: "...", file_path: "..."}, ...]}
  """
  @spec generate_for_story(Story.t(), atom(), keyword()) ::
          {:ok, [%{japanese: String.t(), file_path: String.t()}]} | {:error, term()}
  def generate_for_story(%Story{} = story, voice, opts \\ []) do
    pages = Story.list_pages(story)

    results =
      Enum.flat_map(pages, fn page ->
        case generate_for_page(page, voice, opts) do
          {:ok, page_results} -> page_results
          {:error, _reason} -> []
        end
      end)

    {:ok, results}
  end

  @doc """
  Get a random snippet with audio from a page or story.

  Returns a random snippet that has audio generated for at least one voice.
  Works with both Page and Story structs.

  For a Page: Gets all snippets from that page with audio
  For a Story: Gets all snippets from all pages in the story with audio

  ## Parameters
  - `page_or_story` - A Page or Story struct

  ## Returns
  {:ok, %{
    japanese: "original Japanese text",
    english: "English translation",
    audio_path: "/path/to/audio.mp3",
    voice: :jf_alpha
  }}

  Or {:error, :no_audio_found} if no snippets have audio

  ## Examples
      iex> page = %Page{story: "story1", number: 1}
      iex> Japanese.Corpus.Audio.get_random_snippet_with_audio(page)
      {:ok, %{japanese: "...", english: "...", audio_path: "...", voice: :jf_alpha}}

      iex> story = %Story{name: "story1"}
      iex> Japanese.Corpus.Audio.get_random_snippet_with_audio(story)
      {:ok, %{japanese: "...", english: "...", audio_path: "...", voice: :jf_gongitsune}}
  """
  @spec get_random_snippet_with_audio(Page.t() | Story.t()) ::
          {:ok,
           %{
             japanese: String.t(),
             english: String.t(),
             audio_path: String.t(),
             voice: atom()
           }}
          | {:error, :no_audio_found}
  def get_random_snippet_with_audio(%Page{} = page) do
    storage = StorageLayer.new()

    case get_snippets_with_audio_from_page(page, storage) do
      [] -> {:error, :no_audio_found}
      snippets -> {:ok, Enum.random(snippets)}
    end
  end

  def get_random_snippet_with_audio(%Story{} = story) do
    storage = StorageLayer.new()

    snippets =
      Story.list_pages(story)
      |> Enum.flat_map(fn page -> get_snippets_with_audio_from_page(page, storage) end)

    case snippets do
      [] -> {:error, :no_audio_found}
      snippets -> {:ok, Enum.random(snippets)}
    end
  end

  defp get_snippets_with_audio_from_page(%Page{story: story} = page, storage) do
    case Utils.parse_japanese_statements(page) do
      {:ok, statements} ->
        Enum.flat_map(statements, fn statement ->
          find_audio_for_snippet(statement, story, storage)
        end)

      _ ->
        []
    end
  end

  defp find_audio_for_snippet(statement, story, storage) do
    hash = hash_text(statement.japanese)
    audio_dir = Path.join([storage.working_directory, story, "audio"])

    Enum.flat_map(@valid_voices, fn voice ->
      base_filename = "#{voice}_#{hash}"
      audio_pattern = Path.join(audio_dir, "#{base_filename}.*")

      case Path.wildcard(audio_pattern) do
        [audio_path | _] ->
          [
            %{
              japanese: statement.japanese,
              english: statement.english,
              audio_path: audio_path,
              voice: voice
            }
          ]

        [] ->
          []
      end
    end)
  end

  defp hash_text(text) do
    :crypto.hash(:md5, text)
    |> Base.encode16(case: :lower)
  end
end
