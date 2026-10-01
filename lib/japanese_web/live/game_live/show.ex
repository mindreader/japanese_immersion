defmodule JapaneseWeb.GameLive.Show do
  @moduledoc """
  Game screenshot study view.

  `/game` shows the newest shot; `/game/:id` a particular one. Older / Newer
  step through the history, and the list at the top browses it.

  A screenshot arriving from the Deck never moves you off what you are
  reading: it shows a banner ("New screenshot … View") that follows it
  while it is processed, and you go to it when you choose. Only an empty
  page (no shots yet) switches to the new one by itself.

  English and the kana readings start hidden so you can try reading first;
  their buttons reveal them. The Japanese is always shown. The toggles are
  `JS.toggle_class` on the text container, which LiveView keeps across
  server updates; the container's id changes with the shot, so each shot
  starts with English and kana hidden again. Selecting Japanese text offers
  JPDB / Explain, as on the story page.
  """
  use JapaneseWeb, :live_view

  require Logger

  alias Japanese.Games
  alias Japanese.Games.Processor
  alias JapaneseWeb.TranslationErrors

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Games.subscribe()

    {:ok,
     assign(socket,
       page_title: "Game",
       shots: Games.list_shots(),
       shot: nil,
       arrived: nil,
       deck_status: Games.deck_status(),
       selected_text: nil,
       explaining: false,
       explanation: nil,
       explain_task: nil
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _uri, socket) do
    case Games.get_shot(id) do
      {:ok, shot} ->
        {:noreply, show_shot(socket, shot)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Screenshot not found.")
         |> push_patch(to: ~p"/game")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, show_shot(socket, List.first(socket.assigns.shots))}
  end

  defp show_shot(socket, shot) do
    socket
    |> assign(:shot, shot)
    |> update(:arrived, fn arrived ->
      if shot && arrived && arrived.id == shot.id, do: nil, else: arrived
    end)
    |> assign(:page_title, if(shot, do: shot.description || "Game", else: "Game"))
    |> assign(:selected_text, nil)
  end

  @impl Phoenix.LiveView
  def handle_info({:shot_added, shot}, socket) do
    socket = assign(socket, :shots, Games.list_shots())

    if socket.assigns.shot do
      {:noreply, assign(socket, :arrived, shot)}
    else
      {:noreply, push_patch(socket, to: ~p"/game/#{shot.id}")}
    end
  end

  def handle_info({:shot_updated, shot}, socket) do
    socket =
      socket
      |> assign(:shots, Games.list_shots())
      |> update(:arrived, fn arrived ->
        if arrived && arrived.id == shot.id, do: shot, else: arrived
      end)

    if socket.assigns.shot && socket.assigns.shot.id == shot.id do
      {:noreply, assign(socket, :shot, shot)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deck_status, status}, socket) do
    {:noreply, assign(socket, :deck_status, status)}
  end

  def handle_info({ref, result}, socket) when is_reference(ref) do
    cond do
      task_ref(socket.assigns.explain_task) == ref ->
        Process.demonitor(ref, [:flush])

        explanation =
          case result do
            {:ok, text} ->
              case Earmark.as_html(text) do
                {:ok, html, _} -> html
                {:error, _html, _} -> text
              end

            {:error, message} ->
              message
          end

        {:noreply, assign(socket, explaining: false, explain_task: nil, explanation: explanation)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    cond do
      task_ref(socket.assigns.explain_task) == ref ->
        Logger.warning("Explain task crashed: #{inspect(reason)}")

        {:noreply,
         assign(socket,
           explaining: false,
           explain_task: nil,
           explanation: TranslationErrors.explain_message(reason)
         )}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_event("text_selected", %{"text" => text}, socket) do
    {:noreply, assign(socket, :selected_text, text)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_text, nil)}
  end

  def handle_event("start_explain", %{"text" => text}, socket) do
    task =
      Task.Supervisor.async_nolink(Japanese.TaskSupervisor.name(), fn ->
        case Japanese.Translation.explain_text(text) do
          {:error, reason} ->
            Logger.warning("Explain lookup failed: #{inspect(reason)}")
            {:error, TranslationErrors.explain_message(reason)}

          explanation when is_binary(explanation) ->
            {:ok, explanation}
        end
      end)

    {:noreply, assign(socket, selected_text: text, explaining: true, explain_task: task)}
  end

  def handle_event("cancel_explain", _params, socket) do
    terminate_task(socket.assigns.explain_task)
    {:noreply, assign(socket, explaining: false, explain_task: nil)}
  end

  def handle_event("close_explanation_modal", _params, socket) do
    {:noreply, assign(socket, :explanation, nil)}
  end

  def handle_event("dismiss_arrived", _params, socket) do
    {:noreply, assign(socket, :arrived, nil)}
  end

  def handle_event("retry_shot", _params, %{assigns: %{shot: %{id: id}}} = socket) do
    case Processor.retry(id) do
      :ok ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Can't retry: #{Processor.describe_error(reason)}")}
    end
  end

  # --- helpers for the template ---

  @doc false
  @spec neighbours([Games.Shot.t()], Games.Shot.t() | nil) ::
          {Games.Shot.t() | nil, Games.Shot.t() | nil}
  def neighbours(_shots, nil), do: {nil, nil}

  def neighbours(shots, shot) do
    case Enum.find_index(shots, &(&1.id == shot.id)) do
      nil ->
        {nil, nil}

      index ->
        newer = if index > 0, do: Enum.at(shots, index - 1)
        {Enum.at(shots, index + 1), newer}
    end
  end

  @doc false
  def deck_label(:disabled), do: "Deck watcher off"
  def deck_label(:searching), do: "No Deck connected"
  def deck_label({:connected, name}), do: "Watching #{name}"

  @doc false
  def status_label(:pending), do: "waiting"
  def status_label(:processing), do: "reading…"
  def status_label(:error), do: "failed"
  def status_label(:done), do: nil

  defp task_ref(%Task{ref: ref}), do: ref
  defp task_ref(nil), do: nil

  defp terminate_task(%Task{pid: pid}),
    do: Task.Supervisor.terminate_child(Japanese.TaskSupervisor.name(), pid)

  defp terminate_task(nil), do: :ok
end
