defmodule JapaneseWeb.RecentWords do
  @moduledoc """
  The "Recent" word list: the last 30 words looked up on JPDB, so a word met a
  few paragraphs back is easy to find again for review.

  Entirely client-side. The JPDB button is already pure JavaScript (it opens
  jpdb.io in a new tab without involving the server), so `app.js` records each
  lookup in the browser's `localStorage`. That survives the phone pausing and
  the LiveView socket dropping, back buttons, reloads and server restarts —
  none of which the server would. The list is per device.

  The dialog is rendered empty with `phx-update="ignore"` and filled in by the
  `RecentWords` hook each time it opens, so LiveView patches never touch it.
  Words are listed oldest to newest, and the dialog opens scrolled to the
  bottom so the newest sit just above its buttons. They are ordinary
  selectable text: select one (or part of one) and press JPDB to look it up
  again, which moves it back to the bottom.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc "The button that opens the dialog. Small, for the page header."
  attr :class, :any, default: nil

  def open_button(assigns) do
    ~H"""
    <button
      type="button"
      id="recent-words-open"
      phx-click={JS.dispatch("recent-words:open", to: "#recent-words-modal")}
      class={[
        "rounded-lg bg-zinc-100 px-3 py-2 text-sm font-semibold text-zinc-800",
        "hover:bg-zinc-200 active:text-zinc-900/80",
        @class
      ]}
    >
      Recent
    </button>
    """
  end

  @doc "The dialog itself. Render once per page, outside any selection hook."
  def dialog(assigns) do
    ~H"""
    <div
      id="recent-words-modal"
      phx-hook="RecentWords"
      phx-update="ignore"
      class="relative z-50 hidden"
      role="dialog"
      aria-modal="true"
      aria-labelledby="recent-words-title"
    >
      <div class="fixed inset-0 bg-zinc-50/90" data-role="backdrop"></div>
      <div class="fixed inset-0 flex items-center justify-center p-4" data-role="backdrop">
        <div class="flex max-h-[85vh] w-full max-w-md flex-col rounded-2xl bg-white p-6 shadow-lg ring-1 ring-zinc-700/10">
          <h3 id="recent-words-title" class="text-lg font-semibold text-zinc-900">
            Recent lookups
          </h3>
          <p class="mt-1 text-xs text-zinc-500">
            Newest at the bottom. Select a word and press JPDB to look it up again.
          </p>
          <p data-role="empty" class="mt-6 hidden text-sm text-zinc-500">
            No lookups yet on this device.
          </p>
          <ol
            data-role="list"
            class="mt-4 flex-1 divide-y divide-zinc-100 overflow-y-auto font-serif text-xl"
          >
          </ol>
          <div class="mt-4 flex justify-end gap-3 border-t border-zinc-200 pt-4">
            <button
              type="button"
              data-role="jpdb"
              disabled
              class="rounded-lg bg-blue-600 px-6 py-2 text-white shadow hover:bg-blue-700 disabled:opacity-30"
            >
              JPDB
            </button>
            <button
              type="button"
              data-role="close"
              class="rounded-lg bg-zinc-900 px-6 py-2 text-white shadow hover:bg-zinc-700"
            >
              Okay
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
