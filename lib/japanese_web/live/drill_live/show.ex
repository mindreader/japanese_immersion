defmodule JapaneseWeb.DrillLive.Show do
  @moduledoc """
  Verb conjugation drill — flashcard-style flow.

  The session state is `{history, cursor}`. Each entry in history is a
  `Japanese.Drill.present/2` map. `Next` at the end of history appends a new
  random prompt; `Back` walks the cursor backward (and auto-reveals so you can
  compare). State is purely ephemeral — navigating away resets it.
  """

  use JapaneseWeb, :live_view

  require Logger

  alias Japanese.Drill
  alias JapaneseWeb.TranslationErrors

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Verb Drill")
     |> assign(:history, [Drill.random()])
     |> assign(:cursor, 0)
     |> assign(:revealed, false)
     |> assign(:explanation, nil)
     |> assign(:explaining, false)
     |> assign(:explain_task, nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("reveal", _params, socket) do
    {:noreply, assign(socket, :revealed, true)}
  end

  def handle_event("next", _params, socket) do
    %{history: history, cursor: cursor} = socket.assigns
    new_cursor = cursor + 1

    new_history =
      if new_cursor >= length(history) do
        history ++ [Drill.random()]
      else
        history
      end

    {:noreply,
     socket
     |> assign(:history, new_history)
     |> assign(:cursor, new_cursor)
     |> assign(:revealed, false)
     |> reset_explain()}
  end

  def handle_event("back", _params, socket) do
    new_cursor = max(socket.assigns.cursor - 1, 0)

    {:noreply,
     socket
     |> assign(:cursor, new_cursor)
     |> assign(:revealed, true)
     |> reset_explain()}
  end

  def handle_event("start_explain", _params, socket) do
    current = current(socket.assigns)

    payload = %{
      verb_kanji: current.verb.kanji,
      verb_kana: current.verb.kana,
      verb_english: current.verb.english,
      verb_class: current.verb.class,
      form_label: current.help.label,
      conjugated_kanji: current.kanji,
      conjugated_kana: current.prompt
    }

    task =
      Task.Supervisor.async_nolink(Japanese.TaskSupervisor.name(), fn ->
        case Japanese.Translation.explain_form(payload) do
          {:error, reason} ->
            Logger.warning("Drill explain lookup failed: #{inspect(reason)}")
            {:error, TranslationErrors.explain_message(reason)}

          text when is_binary(text) ->
            {:ok, text}
        end
      end)

    {:noreply,
     socket
     |> assign(:explaining, true)
     |> assign(:explain_task, task)}
  end

  def handle_event("cancel_explain", _params, socket) do
    case socket.assigns.explain_task do
      %Task{} = task -> Task.Supervisor.terminate_child(Japanese.TaskSupervisor.name(), task.pid)
      nil -> :ok
    end

    {:noreply, socket |> assign(:explaining, false) |> assign(:explain_task, nil)}
  end

  @impl Phoenix.LiveView
  def handle_info({ref, result}, socket) when is_reference(ref) do
    if explain_task_ref(socket) == ref do
      Process.demonitor(ref, [:flush])

      explanation =
        case result do
          {:ok, text} ->
            case Earmark.as_html(text) do
              {:ok, html, _messages} -> html
              {:error, _html, _messages} -> text
            end

          {:error, message} ->
            message
        end

      {:noreply,
       socket
       |> assign(:explaining, false)
       |> assign(:explain_task, nil)
       |> assign(:explanation, explanation)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    if explain_task_ref(socket) == ref do
      Logger.warning("Drill explain task crashed: #{inspect(reason)}")

      {:noreply,
       socket
       |> assign(:explaining, false)
       |> assign(:explain_task, nil)
       |> assign(:explanation, TranslationErrors.explain_message(reason))}
    else
      {:noreply, socket}
    end
  end

  defp reset_explain(socket) do
    socket
    |> assign(:explanation, nil)
    |> assign(:explaining, false)
    |> assign(:explain_task, nil)
  end

  defp explain_task_ref(socket) do
    case socket.assigns.explain_task do
      %Task{ref: ref} -> ref
      nil -> nil
    end
  end

  defp current(%{history: history, cursor: cursor}), do: Enum.at(history, cursor)
end
