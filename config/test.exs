import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :japanese, JapaneseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "JrxeoWbuylR8tXra10O0cW4Du586QnEf2WA1UdTBcUR1CJRBIPb/6QdPj2Toa8Uf",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Set a fake corpus directory for tests
config :japanese, Japanese.Corpus.StorageLayer, corpus_dir: System.tmp_dir!()

config :japanese, Japanese.Translation, api_key: "dummy-key"
