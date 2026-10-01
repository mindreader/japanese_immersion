defmodule Japanese.GamesCase do
  @moduledoc """
  Points `Japanese.Games` at a fresh temporary directory for each test, and
  provides `eventually/1` for waiting on the asynchronous processor.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Japanese.GamesCase
    end
  end

  setup do
    dir = Briefly.create!(directory: true)
    previous = Application.get_env(:japanese, Japanese.Games)
    Application.put_env(:japanese, Japanese.Games, dir: dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:japanese, Japanese.Games, previous),
        else: Application.delete_env(:japanese, Japanese.Games)
    end)

    %{games_dir: dir}
  end

  def eventually(fun, retries \\ 200) do
    cond do
      fun.() -> :ok
      retries <= 0 -> ExUnit.Assertions.flunk("condition was never satisfied")
      true -> Process.sleep(10) && eventually(fun, retries - 1)
    end
  end
end
