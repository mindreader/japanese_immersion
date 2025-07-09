defmodule Japanese.Events.Page do
  @moduledoc """
  Event utilities for page-level events.
  """

  @spec subscribe_page(Japanese.Corpus.Page.t()) :: :ok
  def subscribe_page(%Japanese.Corpus.Page{story: story, number: page}) do
    Phoenix.PubSub.subscribe(Japanese.PubSub, "story:#{story}:page:#{page}")
  end

  @spec unsubscribe_page(Japanese.Corpus.Page.t()) :: :ok
  def unsubscribe_page(%Japanese.Corpus.Page{story: story, number: page}) do
    Phoenix.PubSub.unsubscribe(Japanese.PubSub, "story:#{story}:page:#{page}")
  end

  @spec translation_finished(Japanese.Corpus.Page.t()) :: :ok
  def translation_finished(%Japanese.Corpus.Page{story: story, number: page}) do
    Phoenix.PubSub.broadcast(
      Japanese.PubSub,
      "story:#{story}:page:#{page}",
      {:translation_finished, %{story: story, page: page}}
    )

    :ok
  end
end
