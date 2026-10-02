defmodule Japanese.HTTP do
  @moduledoc """
  Shared HTTP client settings.

  ## Why the API clients send `Connection: close`

  Anthropic and Google Vision calls ask the server to close the connection
  after each response, so no connection to them is ever kept idle in the
  `Japanese.Finch` pool.

  An idle pooled connection can die silently: a router, NAT or the far end's
  load balancer forgets it without either side being told. Finch then closes
  it from *inside the pool process*, either when it has been idle longer than
  `conn_max_idle_time` and is next checked out, or when a request using it is
  killed (Explain cancelled, a translation/screenshot task timed out). Erlang's
  TLS close sends a close alert and waits up to 5s for the peer, which never
  answers on a dead path, so the whole pool is frozen for 5s. That equals
  Finch's default `pool_timeout`, so the request waiting on the pool fails
  with "Finch was unable to provide a connection within the timeout due to
  excess queuing for connections", even with a single user. (Before idle
  connections were recycled, the same dead connections were reused instead
  and failed as phantom receive timeouts.) See
  https://github.com/dashbitco/nimble_pool/issues/45.

  With `Connection: close`, the server replies `Connection: close` too and
  Mint closes the socket in the requesting process as soon as the response is
  complete; the connection is never checked back in, so there is nothing for
  the pool to close later. This relies on the server echoing the header
  (Mint decides from the response, not the request): Cloudflare in front of
  Anthropic and Google's front end both do. If one ever stopped, behaviour
  would quietly fall back to ordinary keep-alive, no worse than before.

  The cost is a fresh TCP+TLS handshake (~100ms) per call, negligible next to
  LLM/OCR calls that take seconds.
  """

  @doc """
  Request headers that stop a connection from being returned to the pool.
  """
  @spec no_keepalive_headers() :: [{String.t(), String.t()}]
  def no_keepalive_headers, do: [{"connection", "close"}]
end
