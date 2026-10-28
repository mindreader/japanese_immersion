import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/japanese start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :japanese, JapaneseWeb.Endpoint, server: true
end

# Google Cloud Vision OCR for game screenshots (an API key restricted to the
# Vision API). Without it, screenshots are still found but fail to process.
# GOOGLE_VISION_MODEL is optional ("builtin/latest" or "builtin/stable");
# unset, Google picks (builtin/stable).
config :japanese, Japanese.Games.Vision,
  api_key: System.get_env("GOOGLE_VISION_API_KEY"),
  model: System.get_env("GOOGLE_VISION_MODEL")

# Private key for SSH to the Steam Deck (its public half goes in the Deck's
# ~/.ssh/authorized_keys). Unset: ~/.ssh/steamdeck_ed25519 if it exists,
# otherwise ssh's defaults. See Japanese.Games.Deck.
config :japanese, Japanese.Games.Deck, ssh_key: System.get_env("DECK_SSH_KEY")

if config_env() != :test do
  # The translation model chain: comma-separated "provider/model" entries,
  # tried in order until one answers, e.g.
  #   TRANSLATION_CHAIN=anthropic/claude-opus-5,openrouter/deepseek/deepseek-v4.1-flash
  # TRANSLATION_CHAIN_<OPERATION> overrides it for one operation (JA_TO_EN,
  # EN_TO_JA, EXPLAIN, SCREENSHOT; screenshots need vision models). Unset or
  # empty: the built-in default. Checked at startup; see
  # Japanese.Translation.chain/1.
  config :japanese, Japanese.Translation,
    api_key: System.get_env("ANTHROPIC_API_KEY"),
    chain: System.get_env("TRANSLATION_CHAIN"),
    chains: %{
      ja_to_en: System.get_env("TRANSLATION_CHAIN_JA_TO_EN"),
      en_to_ja: System.get_env("TRANSLATION_CHAIN_EN_TO_JA"),
      explain: System.get_env("TRANSLATION_CHAIN_EXPLAIN"),
      screenshot: System.get_env("TRANSLATION_CHAIN_SCREENSHOT")
    }

  # Optional. Enables the "openrouter/..." entries of the translation model
  # chain (see Japanese.Translation.chain/1); without it they are skipped.
  config :japanese, Japanese.OpenRouter, api_key: System.get_env("OPENROUTER_API_KEY")

  corpus_dir =
    System.get_env(
      "CORPUS_DIR",
      if config_env() == :dev do
        "txt"
      end
    )

  config :japanese, Japanese.Corpus.StorageLayer, corpus_dir: corpus_dir
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || System.get_env("HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :japanese, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :japanese, JapaneseWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    # we are accessing this often by ip.
    check_origin: false
end
