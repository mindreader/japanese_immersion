defmodule JapaneseWeb.TranslationErrors do
  @moduledoc """
  Maps a `Japanese.Translation` failure reason to a short, mobile-safe,
  user-facing sentence.

  This exists because a failure reason from the translation layer can be
  (and, in production, has been) an `Ecto.Changeset` — Anthropic response
  validation failing produces one, and it used to reach the screen via
  `inspect/1`, rendering as a ~650-character struct dump on a phone
  ("Failed to generate explanation: #Ecto.Changeset<...>"). `reason` here is
  treated as opaque and untrusted: it can be an atom today and something
  else tomorrow, so every clause below returns a fixed, hand-written string
  and never interpolates `reason` itself. That is the one rule this module
  exists to enforce in a single place, so a new call site can't
  reintroduce the bug by skipping it.

  The gory detail (the actual `reason`) belongs in `Logger.warning` at the
  call site, not on screen — see callers in `JapaneseWeb.PageLive.Show` and
  `JapaneseWeb.DrillLive.Show`.
  """

  @doc """
  User-facing message for a failed explanation — both the page's word/phrase
  breakdown and the drill's per-form note go through this, since both call
  `Japanese.Translation.explain_text/1` or `explain_form/1` and can fail the
  same way. It is deliberately a single generic sentence.
  """
  @spec explain_message(term()) :: String.t()
  def explain_message(_reason),
    do: "Failed to generate explanation. Please try again."

  @doc """
  User-facing message for a page translation that failed, shown on the page
  with a Retry button. Refusals get their own wording, because retrying the
  same model rarely helps and the details are only in the server log.
  """
  @spec translation_message(term()) :: String.t()
  def translation_message(:refused),
    do: "The model declined to translate this page, and no other model was available to try."

  def translation_message({:all_models_failed, failures}) when is_list(failures) do
    if Enum.all?(failures, &match?({_entry, :refused}, &1)),
      do: "Every model in the chain declined to translate this page.",
      else: "Every model in the chain failed. The server log has the details."
  end

  def translation_message(:no_model_available),
    do: "No translation model is available. Check the API keys."

  def translation_message(:timeout), do: "Translation timed out. Please try again."

  def translation_message(_reason),
    do: "Translation failed. Please try again; the server log has the details."
end
