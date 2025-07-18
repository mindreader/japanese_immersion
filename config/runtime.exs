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

if config_env() == :prod do
  # Not using a database for now, but perhaps in the future

  # database_url =
  #   System.get_env("DATABASE_URL") ||
  #     raise """
  #     environment variable DATABASE_URL is missing.
  #     For example: ecto://USER:PASS@HOST/DATABASE
  #     """

  # maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # config :japanese, Japanese.Repo,
  #   # ssl: true,
  #   url: database_url,
  #   pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  #   socket_options: maybe_ipv6

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

if config_env() == :prod do
  config :japanese, anthropic_api_key: System.fetch_env!("ANTHROPIC_API_KEY")
end

if config_env() == :dev do
  key = System.get_env("ANTHROPIC_API_KEY")

  if !key do
    IO.puts("Warning: ANTHROPIC_API_KEY is not set. Calls to the Anthropic API will fail.")
  end

  config :japanese, anthropic_api_key: key
end

if config_env() == :prod do
  config :japanese, corpus_dir: System.fetch_env!("CORPUS_DIR")
end

if config_env() == :dev do
  config :japanese, corpus_dir: System.get_env("CORPUS_DIR", "txt")
end

timeout = System.get_env("TRANSLATION_TIMEOUT_SECONDS", "20") |> String.to_integer()

config :japanese, Japanese.Translation.Service, timeout: :timer.seconds(timeout)
