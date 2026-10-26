defmodule JapaneseWeb.HomeLive do
  @moduledoc """
  The top level: pick a mode (Stories, Game, Drill) and set the colour theme.
  Every other page leads back here.
  """
  use JapaneseWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Home")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.header>
      Japanese
      <:subtitle>Pick something to practise.</:subtitle>
    </.header>

    <nav class="mt-8 grid gap-4 sm:grid-cols-3">
      <.mode_card
        id="mode-stories"
        navigate={~p"/stories"}
        icon="hero-book-open"
        title="Stories"
        accent="text-blue-600 dark:text-blue-400"
      >
        Read translated stories and practise listening.
      </.mode_card>
      <.mode_card
        id="mode-game"
        navigate={~p"/game"}
        icon="hero-camera"
        title="Game"
        accent="text-amber-600 dark:text-amber-400"
      >
        Read text from Steam Deck screenshots.
      </.mode_card>
      <.mode_card
        id="mode-drill"
        navigate={~p"/drill"}
        icon="hero-arrow-path-rounded-square"
        title="Drill"
        accent="text-green-600 dark:text-green-400"
      >
        Recognise conjugated verbs.
      </.mode_card>
    </nav>

    <section class="mt-12 flex items-center justify-between gap-4 border-t border-zinc-200 pt-6 dark:border-zinc-800">
      <h2 class="text-sm font-semibold text-zinc-800 dark:text-zinc-200">Appearance</h2>
      <.theme_toggle />
    </section>
    """
  end

  attr :id, :string, required: true
  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :accent, :string, required: true
  slot :inner_block, required: true

  defp mode_card(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@navigate}
      class={[
        "block rounded-2xl border border-zinc-200 p-5 shadow-sm transition",
        "hover:border-zinc-300 hover:bg-zinc-50",
        "dark:border-zinc-800 dark:bg-zinc-900 dark:hover:border-zinc-700 dark:hover:bg-zinc-800"
      ]}
    >
      <.icon name={@icon} class={"h-7 w-7 #{@accent}"} />
      <div class="mt-3 text-lg font-semibold text-zinc-900 dark:text-zinc-100">{@title}</div>
      <p class="mt-1 text-sm text-zinc-600 dark:text-zinc-400">{render_slot(@inner_block)}</p>
    </.link>
    """
  end
end
