defmodule Test.JapaneseWeb.TranslationErrors do
  use ExUnit.Case, async: true

  alias JapaneseWeb.TranslationErrors

  # Regression tests for the actual user complaint: selecting a long phrase
  # used to surface a 654-character `inspect/1`ed Ecto.Changeset on screen
  # ("Could not look up reading: #Ecto.Changeset<...>"). This is the one
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

  describe "reading_message/1" do
    test "gives :truncated its own short, actionable sentence" do
      message = TranslationErrors.reading_message(:truncated)
      assert message =~ "shorter"
      refute_debris(message)
    end

    test "collapses any other reason to one short generic sentence" do
      for reason <- [
            :invalid_response,
            :no_usable_text,
            :llm_error,
            :timeout,
            {:some, "arbitrary", :term},
            %RuntimeError{message: "boom"}
          ] do
        refute_debris(TranslationErrors.reading_message(reason))
      end
    end

    test "never leaks a raw changeset (the original bug), even if one is passed in" do
      refute_debris(TranslationErrors.reading_message(a_changeset()))
    end
  end

  describe "explain_message/1" do
    test "never suggests shortening — there's nothing to shorten in an explanation" do
      message = TranslationErrors.explain_message(:timeout)
      refute message =~ "shorter"
      refute_debris(message)
    end

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
end
