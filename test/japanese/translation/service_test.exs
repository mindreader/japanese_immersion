defmodule Test.Japanese.Translation.Service do
  use ExUnit.Case, async: true
  use Mimic

  alias Japanese.Translation.Service.Server
  alias Japanese.Corpus.Page

  setup :verify_on_exit!

  @page %Page{story: "test_story", number: 1}
  @key {"test_story", 1}

  describe "Server.init/1" do
    test "initializes with empty statuses and no tracked tasks" do
      assert {:ok, %{statuses: %{}, tasks: %{}}} = Server.init(%{})
    end
  end

  describe "Server.handle_call {:get_status, key}" do
    test "returns nil when key not in state" do
      state = %{statuses: %{}}
      assert {:reply, nil, ^state} = Server.handle_call({:get_status, @key}, self(), state)
    end

    test "returns :in_progress when translation is running" do
      state = %{statuses: %{@key => :in_progress}}

      assert {:reply, :in_progress, ^state} =
               Server.handle_call({:get_status, @key}, self(), state)
    end

    test "returns error tuple when translation failed" do
      state = %{statuses: %{@key => {:error, :some_reason}}}

      assert {:reply, {:error, :some_reason}, ^state} =
               Server.handle_call({:get_status, @key}, self(), state)
    end
  end

  describe "Server.handle_call :list_statuses" do
    test "returns all statuses" do
      statuses = %{
        {"story1", 1} => :in_progress,
        {"story2", 2} => {:error, :timeout}
      }

      state = %{statuses: statuses}
      assert {:reply, ^statuses, ^state} = Server.handle_call(:list_statuses, self(), state)
    end
  end

  describe "Server.handle_cast {:translate_page, page}" do
    @tag capture_log: true
    test "skips if already in progress" do
      state = %{statuses: %{@key => :in_progress}}
      assert {:noreply, ^state} = Server.handle_cast({:translate_page, @page}, state)
    end

    test "sets status to in_progress and broadcasts translation_started" do
      state = %{statuses: %{}, tasks: %{}}

      Phoenix.PubSub.subscribe(Japanese.PubSub, "story:test_story:page:1")

      {:noreply, new_state} = Server.handle_cast({:translate_page, @page}, state)

      assert new_state.statuses[@key] == :in_progress
      assert map_size(new_state.tasks) == 1
      assert_receive {:translation_started, %{story: "test_story", page: 1}}
    end
  end

  describe "Server.handle_cast {:clear_error, key}" do
    test "clears error status" do
      state = %{statuses: %{@key => {:error, :some_error}}}
      assert {:noreply, %{statuses: %{}}} = Server.handle_cast({:clear_error, @key}, state)
    end

    test "does nothing if status is in_progress" do
      state = %{statuses: %{@key => :in_progress}}
      assert {:noreply, ^state} = Server.handle_cast({:clear_error, @key}, state)
    end

    test "does nothing if no status exists" do
      state = %{statuses: %{}}
      assert {:noreply, ^state} = Server.handle_cast({:clear_error, @key}, state)
    end
  end

  # Builds a state with a single tracked task keyed by `ref`, as the server
  # would hold while a translation is running. A live (but harmless) timer is
  # armed so the success/error/crash paths exercise real timer cancellation.
  defp state_with_task(ref) do
    timer = Process.send_after(self(), {:translation_timeout, ref}, 60_000)

    %{
      statuses: %{@key => :in_progress},
      tasks: %{ref => %{key: @key, page: @page, pid: self(), timer: timer}}
    }
  end

  describe "Server.handle_info task success" do
    @tag capture_log: true
    test "clears status and forgets the task on successful translation" do
      ref = make_ref()
      state = state_with_task(ref)

      {:noreply, new_state} = Server.handle_info({ref, {@key, @page, :ok}}, state)

      assert new_state.statuses == %{}
      assert new_state.tasks == %{}
    end
  end

  describe "Server.handle_info task error" do
    @tag capture_log: true
    test "sets error status, forgets the task, and broadcasts translation_failed" do
      ref = make_ref()
      state = state_with_task(ref)

      Phoenix.PubSub.subscribe(Japanese.PubSub, "story:test_story:page:1")

      {:noreply, new_state} =
        Server.handle_info({ref, {@key, @page, {:error, :api_error}}}, state)

      assert new_state.statuses[@key] == {:error, :api_error}
      assert new_state.tasks == %{}
      assert_receive {:translation_failed, %{story: "test_story", page: 1, reason: :api_error}}
    end
  end

  describe "Server.handle_info task crash" do
    @tag capture_log: true
    test "attributes the crash to its page, records a retryable error, and notifies" do
      ref = make_ref()
      state = state_with_task(ref)

      Phoenix.PubSub.subscribe(Japanese.PubSub, "story:test_story:page:1")

      {:noreply, new_state} =
        Server.handle_info({:DOWN, ref, :process, self(), :killed}, state)

      assert new_state.statuses[@key] == {:error, :crashed}
      assert new_state.tasks == %{}
      assert_receive {:translation_failed, %{story: "test_story", page: 1, reason: :crashed}}
    end

    @tag capture_log: true
    test "ignores a DOWN for a ref it no longer tracks" do
      state = %{statuses: %{}, tasks: %{}}

      assert {:noreply, ^state} =
               Server.handle_info({:DOWN, make_ref(), :process, self(), :normal}, state)
    end
  end

  describe "Server.handle_info translation timeout" do
    @tag capture_log: true
    test "records :timeout, forgets the task, and notifies when the ceiling fires" do
      ref = make_ref()
      state = state_with_task(ref)

      Phoenix.PubSub.subscribe(Japanese.PubSub, "story:test_story:page:1")

      {:noreply, new_state} = Server.handle_info({:translation_timeout, ref}, state)

      assert new_state.statuses[@key] == {:error, :timeout}
      assert new_state.tasks == %{}
      assert_receive {:translation_failed, %{story: "test_story", page: 1, reason: :timeout}}
    end

    test "ignores a stale timeout for a task that already finished" do
      state = %{statuses: %{}, tasks: %{}}

      assert {:noreply, ^state} =
               Server.handle_info({:translation_timeout, make_ref()}, state)
    end
  end

  describe "Server.handle_info catch-all" do
    @tag capture_log: true
    test "logs and ignores an unrecognised message" do
      state = %{statuses: %{}, tasks: %{}}

      assert {:noreply, ^state} = Server.handle_info(:something_unexpected, state)
    end
  end
end
