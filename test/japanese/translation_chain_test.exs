defmodule Test.Japanese.Translation.Chain do
  # Changes the application config, so not async.
  use ExUnit.Case, async: false
  use Mimic

  alias Japanese.Translation

  setup do
    original = Application.get_env(:japanese, Translation, [])
    on_exit(fn -> Application.put_env(:japanese, Translation, original) end)
    :ok
  end

  describe "chain/1" do
    test "defaults to Anthropic first, then OpenRouter entries" do
      Application.put_env(:japanese, Translation, api_key: "dummy-key")

      for operation <- [:ja_to_en, :en_to_ja, :explain, :screenshot] do
        assert ["anthropic/claude-sonnet-5-5" | rest] = Translation.chain(operation)
        assert rest != []
        assert Enum.all?(rest, &String.starts_with?(&1, "openrouter/"))
      end
    end

    test "a shared :chain applies to every operation" do
      chain = ["anthropic/claude-opus-5", "openrouter/google/gemini-3.8-flash"]
      Application.put_env(:japanese, Translation, api_key: "dummy-key", chain: chain)

      assert Translation.chain(:ja_to_en) == chain
      assert Translation.chain(:explain) == chain
    end

    test "a per-operation entry in :chains overrides it, and a string is one entry" do
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        chain: ["anthropic/claude-opus-5"],
        chains: %{explain: "anthropic/claude-haiku-5"}
      )

      assert Translation.chain(:explain) == ["anthropic/claude-haiku-5"]
      assert Translation.chain(:ja_to_en) == ["anthropic/claude-opus-5"]
    end

    test "a comma-separated string (as from TRANSLATION_CHAIN) is split and trimmed" do
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        chain: " anthropic/claude-opus-5 , openrouter/google/gemini-3.8-flash,",
        chains: %{screenshot: "openrouter/google/gemini-3.8-flash"}
      )

      assert Translation.chain(:ja_to_en) ==
               ["anthropic/claude-opus-5", "openrouter/google/gemini-3.8-flash"]

      assert Translation.chain(:screenshot) == ["openrouter/google/gemini-3.8-flash"]
    end

    test "unset or empty values fall through, as runtime.exs passes them" do
      # What config/runtime.exs produces with no TRANSLATION_CHAIN* set...
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        chain: nil,
        chains: %{ja_to_en: nil, en_to_ja: nil, explain: nil, screenshot: nil}
      )

      default = Translation.chain(:ja_to_en)
      assert ["anthropic/" <> _ | _] = default

      # ...and with some set to empty strings or just commas.
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        chain: "",
        chains: %{explain: " , ", ja_to_en: "anthropic/claude-opus-5"}
      )

      assert Translation.chain(:explain) == default
      assert Translation.chain(:en_to_ja) == default
      assert Translation.chain(:ja_to_en) == ["anthropic/claude-opus-5"]
    end

    test "every default entry parses" do
      Application.put_env(:japanese, Translation, api_key: "dummy-key")

      for spec <- Translation.chain(:ja_to_en) do
        assert {provider, model} = Translation.parse_spec(spec)
        assert provider in [:anthropic, :openrouter]
        assert model != ""
      end
    end
  end

  describe "validate_chains!/0" do
    test "returns every operation's chain" do
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        chains: %{explain: "anthropic/claude-haiku-5"}
      )

      chains = Translation.validate_chains!()
      assert Map.keys(chains) |> Enum.sort() == [:en_to_ja, :explain, :ja_to_en, :screenshot]
      assert chains.explain == ["anthropic/claude-haiku-5"]
    end

    test "raises on a bad entry in any operation's chain" do
      Application.put_env(:japanese, Translation,
        api_key: "dummy-key",
        chains: %{screenshot: "anthropic/claude-sonnet-5-5,gemini-3.8-flash"}
      )

      assert_raise ArgumentError, ~r/"gemini-3.8-flash"/, &Translation.validate_chains!/0
    end
  end

  describe "parse_spec/1" do
    test "splits off the provider; the rest is that provider's model id" do
      assert Translation.parse_spec("anthropic/claude-sonnet-5-5") ==
               {:anthropic, "claude-sonnet-5-5"}

      assert Translation.parse_spec("openrouter/anthropic/claude-sonnet-5.5") ==
               {:openrouter, "anthropic/claude-sonnet-5.5"}
    end

    test "rejects an unknown provider or a missing model" do
      for bad <- ["claude-sonnet-5-5", "openai/gpt-6-sol", "anthropic/", "openrouter/"] do
        assert_raise ArgumentError, ~r/bad model chain entry/, fn ->
          Translation.parse_spec(bad)
        end
      end
    end
  end

  describe "no usable provider" do
    test "with no API key for any entry, nothing is called" do
      Application.put_env(:japanese, Translation, api_key: nil)
      Mimic.stub(Japanese.OpenRouter, :configured?, fn -> false end)
      Mimic.reject(&Anthropix.chat/2)

      assert {:error, :no_model_available} = Translation.ja_to_en("テスト", [])
    end
  end
end
