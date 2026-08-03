defmodule Japanese.TaskSupervisor do
  @moduledoc """
  Shared accessor for the application-wide ad-hoc task supervisor.

  Anything that fires off a supervised, non-linked background task (an LLM
  call, a translation job, ...) via `Task.Supervisor.async_nolink/2` should
  go through `name/0` rather than hard-coding `Japanese.Task.Supervisor`, so
  the supervisor can be swapped out via config (e.g. in tests).
  """

  @doc """
  Returns the name of the `Task.Supervisor` process started in
  `Japanese.Application`.
  """
  @spec name() :: atom()
  def name do
    config = Application.get_env(:japanese, __MODULE__, [])

    case config[:name] do
      nil -> Japanese.Task.Supervisor
      other -> other
    end
  end
end
