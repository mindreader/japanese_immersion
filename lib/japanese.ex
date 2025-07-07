defmodule Japanese do
  @moduledoc """
  Japanese keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Generate a random 16 byte string and encode it to base64.
  """
  def random_string() do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
