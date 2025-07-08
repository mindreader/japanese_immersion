defmodule JapaneseWeb.StoryLive.FormComponent do
  use JapaneseWeb, :live_component

  alias Japanese.Corpus.Story

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage story records in your corpus.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="story-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Story</.button>
        </:actions>
      </.simple_form>

      <div class="mt-8">
        <h3 class="text-lg font-semibold leading-8 text-zinc-800">Pages</h3>
        <div class="mt-4">
          <div :if={@pages == []} class="text-sm text-zinc-600">
            No pages found in this story.
          </div>
          <div :if={@pages != []} class="space-y-2">
            <div :for={page <- @pages} class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <span class="text-sm font-medium text-zinc-800">Page #{page.number}</span>
              <span class="text-xs text-zinc-500">Story: {page.story}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{story: story} = assigns, socket) do
    pages = if story.name, do: Story.list_pages(story), else: []
    form = Phoenix.Component.to_form(%{"name" => story.name || ""})
    {:ok, socket |> assign(assigns) |> assign(:form, form) |> assign(:pages, pages)}
  end

  @impl true
  def handle_event("validate", %{"story" => story_params}, socket) do
    errors = if String.trim(story_params["name"] || "") == "", do: [name: {"can't be blank", []}], else: []
    form = Phoenix.Component.to_form(story_params, errors: errors)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("validate", params, socket) do
    # Handles cases like %{"_target" => ["name"], "name" => "foobar2"}
    story_params = Map.take(params, ["name"])
    handle_event("validate", %{"story" => story_params}, socket)
  end

  def handle_event("save", %{"story" => story_params}, socket) do
    save_story(socket, socket.assigns.action, story_params)
  end

  def handle_event("save", params, socket) do
    # Handles cases like %{"name" => "foobar2"}
    story_params = Map.take(params, ["name"])
    handle_event("save", %{"story" => story_params}, socket)
  end

  defp save_story(socket, :edit, %{"name" => new_name}) do
    old_name = socket.assigns.story.name
    new_name = String.trim(new_name)
    cond do
      new_name == "" ->
        form = Phoenix.Component.to_form(%{"name" => new_name}, errors: [name: {"can't be blank", []}])
        {:noreply, assign(socket, form: form)}
      new_name == old_name ->
        {:noreply,
         socket
         |> put_flash(:info, "Story updated successfully (no changes)")
         |> push_patch(to: socket.assigns.patch)}
      true ->
        case Story.rename(old_name, new_name) do
          {:ok, story} ->
            notify_parent({:saved, story})
            {:noreply,
             socket
             |> put_flash(:info, "Story renamed successfully")
             |> push_patch(to: ~p"/stories/#{story}")}
          {:error, reason} ->
            form = Phoenix.Component.to_form(%{"name" => new_name}, errors: [name: {inspect(reason), []}])
            {:noreply, assign(socket, form: form)}
        end
    end
  end

  defp save_story(socket, :new, %{"name" => name}) do
    name = String.trim(name)
    if name == "" do
      form = Phoenix.Component.to_form(%{"name" => name}, errors: [name: {"can't be blank", []}])
      {:noreply, assign(socket, form: form)}
    else
      case Story.create(name) do
        {:ok, story} ->
          notify_parent({:saved, story})
          {:noreply,
           socket
           |> put_flash(:info, "Story created successfully")
           |> push_patch(to: socket.assigns.patch)}
        {:error, reason} ->
          form = Phoenix.Component.to_form(%{"name" => name}, errors: [name: {inspect(reason), []}])
          {:noreply, assign(socket, form: form)}
      end
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
