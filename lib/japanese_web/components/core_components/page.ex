defmodule JapaneseWeb.CoreComponents.Page do
  @moduledoc """
  Provides a component to display a translation page or section.
  """
  use Phoenix.Component

  @doc """
  Renders a translation display component.

  Entries come from `Japanese.Translation.Json` and are one of: a Japanese line
  with its English translation (which may be missing, and is then shown as a
  visible gap rather than an empty box), a separator glyph, or a paragraph break.

  ## Assigns
    * `:id` - required, the unique identifier for the component
    * `:content` - the translation map as specified in Japanese.Translation.Json (default: nil)
  """
  attr :id, :string, required: true, doc: "the unique id for the page component"

  attr :content, :map,
    default: nil,
    doc: "the translation map as specified in Japanese.Translation.Json"

  def translation(assigns) do
    ~H"""
    <div id={@id}>
      <%= if @content && Map.has_key?(@content, :translation) do %>
        <%= for entry <- @content.translation do %>
          <%= case entry_kind(entry) do %>
            <% :paragraph_break -> %>
              <div style="height: 1.5em;"></div>
            <% {:separator, glyph} -> %>
              <div class="tr-sep text-center text-gray-500 font-serif text-lg my-4 select-none">
                {glyph}
              </div>
            <% {:pair, japanese, english} -> %>
              <div :if={japanese} class="tr-ja font-serif text-lg">
                {japanese}
              </div>
              <div :if={is_nil(japanese)} class="tr-ja font-serif text-lg italic text-gray-400">
                (original line missing)
              </div>
              <div
                :if={english}
                class="tr-eng text-blue-900 bg-blue-50 rounded p-2 border border-blue-200 mb-4"
                style="visibility: hidden;"
              >
                {english}
              </div>
              <div
                :if={is_nil(english)}
                class="tr-eng text-amber-800 bg-amber-50 rounded p-2 border border-dashed border-amber-300 mb-4 italic"
                style="visibility: hidden;"
              >
                not translated
              </div>
          <% end %>
        <% end %>
      <% else %>
        <span>No translation content.</span>
      <% end %>
    </div>
    """
  end

  @spec entry_kind(map()) ::
          :paragraph_break
          | {:separator, String.t()}
          | {:pair, String.t() | nil, String.t() | nil}
  defp entry_kind(%{paragraph_break: _}), do: :paragraph_break
  defp entry_kind(%{separator: glyph}), do: {:separator, glyph}

  defp entry_kind(entry),
    do: {:pair, Map.get(entry, :japanese), Map.get(entry, :english)}
end
