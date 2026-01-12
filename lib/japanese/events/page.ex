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

  @spec translation_started(Japanese.Corpus.Page.t()) :: :ok
  def translation_started(%Japanese.Corpus.Page{story: story, number: page}) do
    Phoenix.PubSub.broadcast(
      Japanese.PubSub,
      "story:#{story}:page:#{page}",
      {:translation_started, %{story: story, page: page}}
    )

    :ok
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

  @spec translation_failed(Japanese.Corpus.Page.t(), term()) :: :ok
  def translation_failed(%Japanese.Corpus.Page{story: story, number: page}, reason) do
    Phoenix.PubSub.broadcast(
      Japanese.PubSub,
      "story:#{story}:page:#{page}",
      {:translation_failed, %{story: story, page: page, reason: reason}}
    )

    :ok
  end
end
