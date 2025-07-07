defmodule Japanese.Repo do
  use Ecto.Repo,
    otp_app: :japanese,
    adapter: Ecto.Adapters.Postgres
end
