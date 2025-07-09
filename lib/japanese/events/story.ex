defmodule Japanese.Events.Story do
  @moduledoc """
  Event utilities for story-level events.
  """

  alias Japanese.Corpus.Story

  @spec subscribe_story(Story.t()) :: :ok
  def subscribe_story(%Story{name: story}) do
    Phoenix.PubSub.subscribe(Japanese.PubSub, "story:#{story}")
  end

  @spec subscribe_story_pages(Story.t()) :: :ok
  def subscribe_story_pages(%Story{name: story}) do
    Phoenix.PubSub.subscribe(Japanese.PubSub, "story:#{story}:pages")
  end

  @spec unsubscribe_story(Story.t()) :: :ok
  def unsubscribe_story(%Story{name: story}) do
    Phoenix.PubSub.unsubscribe(Japanese.PubSub, "story:#{story}")
  end

  @spec unsubscribe_story_pages(Story.t()) :: :ok
  def unsubscribe_story_pages(%Story{name: story}) do
    Phoenix.PubSub.unsubscribe(Japanese.PubSub, "story:#{story}:pages")
  end

  @spec story_deleted(Story.t()) :: :ok
  def story_deleted(%Story{name: story}) do
    Phoenix.PubSub.broadcast(Japanese.PubSub, "story:#{story}", {:story_deleted, %{story: story}})

    :ok
  end

  @spec story_renamed(Story.t(), String.t()) :: :ok
  def story_renamed(%Story{name: story}, to) do
    Phoenix.PubSub.broadcast(
      Japanese.PubSub,
      "story:#{story}",
      {:story_renamed, %{story: story, to: to}}
    )

    :ok
  end

  @spec pages_updated(Story.t()) :: :ok
  def pages_updated(%Story{name: story}) do
    Phoenix.PubSub.broadcast(
      Japanese.PubSub,
      "story:#{story}:pages",
      {:pages_updated, %{story: story}}
    )

    :ok
  end
end
