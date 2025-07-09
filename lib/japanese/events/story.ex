defmodule Japanese.Events.Story do
  @moduledoc """
  Event utilities for story-level events.
  """

  @spec pages_updated(Japanese.Corpus.Story.t()) :: :ok
  def pages_updated(%Japanese.Corpus.Story{name: story}) do
    Phoenix.PubSub.broadcast(
      Japanese.PubSub,
      "story:#{story}",
      {:pages_updated, %{story: story}}
    )
    :ok
  end
end
