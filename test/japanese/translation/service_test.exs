defmodule Test.Japanese.Translation.Service do
  use ExUnit.Case, async: true
  use Mimic

  alias Japanese.Translation.Service.Server
  alias Japanese.Corpus.Page

  setup :verify_on_exit!

  @page %Page{story: "test_story", number: 1}
  @key {"test_story", 1}

  describe "Server.init/1" do
    test "initializes with empty statuses" do
      assert {:ok, %{statuses: %{}}} = Server.init(%{})
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
      state = %{statuses: %{}}

      Phoenix.PubSub.subscribe(Japanese.PubSub, "story:test_story:page:1")

      {:noreply, new_state} = Server.handle_cast({:translate_page, @page}, state)

      assert new_state.statuses[@key] == :in_progress
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

  describe "Server.handle_info task success" do
    @tag capture_log: true
    test "clears status on successful translation" do
      state = %{statuses: %{@key => :in_progress}}
      ref = make_ref()

      {:noreply, new_state} = Server.handle_info({ref, {@key, @page, :ok}}, state)

      assert new_state.statuses == %{}
    end
  end

  describe "Server.handle_info task error" do
    @tag capture_log: true
    test "sets error status and broadcasts translation_failed" do
      state = %{statuses: %{@key => :in_progress}}
      ref = make_ref()

      Phoenix.PubSub.subscribe(Japanese.PubSub, "story:test_story:page:1")

      {:noreply, new_state} =
        Server.handle_info({ref, {@key, @page, {:error, :api_error}}}, state)

      assert new_state.statuses[@key] == {:error, :api_error}
      assert_receive {:translation_failed, %{story: "test_story", page: 1, reason: :api_error}}
    end
  end

  describe "Server.handle_info task crash" do
    @tag capture_log: true
    test "logs error on task crash" do
      state = %{statuses: %{@key => :in_progress}}

      {:noreply, ^state} =
        Server.handle_info({:DOWN, make_ref(), :process, self(), :killed}, state)
    end
  end
end
