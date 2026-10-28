defmodule Test.JapaneseWeb.TranslationErrors do
  use ExUnit.Case, async: true

  alias JapaneseWeb.TranslationErrors

  # Regression tests for the actual user complaint: a failed lookup used to
  # surface a 654-character `inspect/1`ed Ecto.Changeset on screen. This is the one
  # place that rule is asserted; LiveView tests only need to prove they call
  # into it, not re-derive these checks.
  @max_message_length 120

  defp refute_debris(message) do
    refute message =~ "Ecto.Changeset"
    refute message =~ "%{"
    refute message =~ "#"
    assert String.length(message) <= @max_message_length
  end

  defp a_changeset do
    # A real changeset — the original bug's exact shape — built from the
    # Usage schema without its required fields, so it definitely has errors.
    Japanese.Schemas.Anthropic.Response.Usage.changeset(%{})
  end

  describe "explain_message/1" do
    test "collapses any reason to one short generic sentence" do
      for reason <- [
            :invalid_response,
            :no_usable_text,
            :llm_error,
            :timeout,
            {:some, "arbitrary", :term},
            %RuntimeError{message: "boom"}
          ] do
        refute_debris(TranslationErrors.explain_message(reason))
      end
    end

    test "never leaks a raw changeset, even if one is passed in" do
      refute_debris(TranslationErrors.explain_message(a_changeset()))
    end
  end

  describe "translation_message/1" do
    test "names a refusal instead of calling it an invalid response" do
      assert TranslationErrors.translation_message(:refused) =~ "declined"
      assert TranslationErrors.translation_message(:fallbacks_failed) =~ "fallback models"
      refute TranslationErrors.translation_message(:refused) =~ "invalid"
    end

    test "is short and debris-free for any reason" do
      for reason <- [
            :refused,
            :fallbacks_failed,
            :timeout,
            :crashed,
            :invalid_response,
            {:openrouter_http, 500, "boom"},
            %RuntimeError{message: "boom"},
            a_changeset()
          ] do
        refute_debris(TranslationErrors.translation_message(reason))
      end
    end
  end
end
