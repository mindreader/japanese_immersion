import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :japanese, Japanese.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "japanese_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :japanese, JapaneseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "JrxeoWbuylR8tXra10O0cW4Du586QnEf2WA1UdTBcUR1CJRBIPb/6QdPj2Toa8Uf",
  server: false

# In test we don't send emails
config :japanese, Japanese.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Set a fake corpus directory for tests
config :japanese, :corpus_dir, "<test corpus dir>"

config :japanese, :anthropic_api_key, "dummy-key"
