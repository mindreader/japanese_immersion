defmodule JapaneseWeb.CoreComponents.Page do
  @moduledoc """
  Provides a component to display a translation page or section.
  """
  use Phoenix.Component

  @doc """
  Renders a translation display component.

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
          <%= if Map.get(entry, :paragraph_break, false) do %>
            <div style="height: 1.5em;"></div>
          <% else %>
            <div class="font-serif text-lg">
              {entry.japanese}
            </div>
            <div
              class="tr-eng text-blue-900 bg-blue-50 rounded p-2 border border-blue-200 mb-4"
              style="visibility: hidden;"
            >
              {entry.english}
            </div>
          <% end %>
        <% end %>
      <% else %>
        <span>No translation content.</span>
      <% end %>
    </div>
    """
  end
end
