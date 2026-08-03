defmodule Mix.Tasks.Japanese.Corpus.Verify do
  @shortdoc "READ-ONLY: report which translation files in the corpus fail to decode"

  @moduledoc """
  Scans the corpus and reports which translation files fail to decode.

  This task is **strictly read-only**. It opens files with `File.read/1`,
  decodes them in memory, and prints a report; there is no code path in it
  that writes a file, calls the translation API, or touches the network. It
  cannot "fix" anything it finds wrong, on purpose — the corpus this task
  inspects is a couple hundred chapters of irreplaceable translated data with
  no restore path, so a tool that "migrates while it's looking" is exactly
  the risk this task exists to avoid.

      mix japanese.corpus.verify [--corpus-dir PATH] [--verbose]

  ## Options

    * `--corpus-dir` — corpus root to scan. Defaults to the configured
      corpus directory (`config :japanese, Japanese.Corpus.StorageLayer,
      corpus_dir: ...`, ordinarily set from the `CORPUS_DIR` environment
      variable — see `config/runtime.exs`).
    * `--verbose` — also print every page that decoded cleanly. The default
      output is a compact summary plus one line per failure, since a corpus
      is routinely a couple hundred chapters and a per-page log would bury
      the failures that matter.

  ## Exit status

  Exits nonzero if any translation file failed to decode, so this doubles as
  a smoke check (e.g. after copying the corpus to a new machine, or before
  upgrading the app that reads it).
  """

  use Mix.Task

  alias Japanese.Corpus.StorageLayer
  alias Japanese.Corpus.Verify

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [corpus_dir: :string, verbose: :boolean])

    storage = storage_for(opts)
    report = Verify.run(storage)

    print_report(report, Keyword.get(opts, :verbose, false))

    if report.failures != [] do
      Mix.raise(
        "#{length(report.failures)} of #{report.scanned} translation file(s) failed to decode."
      )
    end
  end

  @spec storage_for(keyword()) :: StorageLayer.t()
  defp storage_for(opts) do
    case Keyword.get(opts, :corpus_dir) do
      nil -> StorageLayer.new()
      dir -> %StorageLayer{working_directory: dir}
    end
  end

  @spec print_report(Verify.report(), boolean()) :: :ok
  defp print_report(report, verbose?) do
    Mix.shell().info("Corpus directory: #{report.corpus_dir} (read-only scan)")

    Mix.shell().info(
      "Translation files scanned: #{report.scanned}, decoded cleanly: #{report.ok}"
    )

    if verbose? do
      Mix.shell().info("Pages:")
      Enum.each(report.pages, &print_page/1)
    end

    case report.failures do
      [] -> Mix.shell().info("No failures.")
      failures -> print_failures(failures)
    end

    :ok
  end

  @spec print_failures([Verify.page_result()]) :: :ok
  defp print_failures(failures) do
    Mix.shell().info("Failures:")
    Enum.each(failures, &print_page/1)
  end

  @spec print_page(Verify.page_result()) :: :ok
  defp print_page(%{story: story, page: page, status: :ok}) do
    Mix.shell().info("  #{story}/#{page}: ok")
  end

  defp print_page(%{story: story, page: page, status: {:error, reason}}) do
    Mix.shell().info("  #{story}/#{page}: FAILED — #{reason}")
  end
end
