defmodule Test.Japanese.Schemas.Anthropic.Response do
  use ExUnit.Case, async: true

  alias Japanese.Schemas.Anthropic.Response

  @valid_response %{
    "content" => [%{"text" => "Test understood", "type" => "text"}],
    "id" => "msg_01WWcvFKEMBmjEU2gjnQ5UnJ",
    "model" => "claude-sonnet-4-20250514",
    "role" => "assistant",
    "stop_reason" => "end_turn",
    "stop_sequence" => nil,
    "type" => "message",
    "usage" => %{
      "cache_creation_input_tokens" => 0,
      "cache_read_input_tokens" => 0,
      "input_tokens" => 47,
      "output_tokens" => 5,
      "service_tier" => "standard"
    }
  }

  test "parse_response/1 validates and parses a valid anthropic response" do
    assert {:ok, resp} = Response.parse_response(@valid_response)
    assert resp.id == "msg_01WWcvFKEMBmjEU2gjnQ5UnJ"
    assert resp.model == "claude-sonnet-4-20250514"
    assert resp.role == "assistant"
    assert resp.stop_reason == "end_turn"
    assert resp.stop_sequence == nil
    assert resp.type == "message"
    assert [%{text: "Test understood", type: "text"}] = resp.content
    assert resp.usage.input_tokens == 47
    assert resp.usage.output_tokens == 5
    assert resp.usage.service_tier == "standard"
    assert resp.usage.cache_creation_input_tokens == 0
    assert resp.usage.cache_read_input_tokens == 0
  end

  # These three payload shapes used to fail validation with a "can't be
  # blank" changeset even though each one is a perfectly legitimate Anthropic
  # response — see the reading lookup bug this schema was over-strict for.
  # `parse_response/1` must accept all of them now; it's up to the caller
  # (`Japanese.Translation.handle_response/2`) to decide whether it can find
  # usable text among the content blocks.

  test "parse_response/1 accepts a text block with an empty string (max_tokens hit before any output)" do
    response = %{@valid_response | "content" => [%{"text" => "", "type" => "text"}]}

    assert {:ok, resp} = Response.parse_response(response)
    assert [%{type: "text"}] = resp.content
  end

  test "parse_response/1 accepts a non-text content block with no text key at all" do
    response = %{
      @valid_response
      | "content" => [%{"type" => "thinking", "thinking" => "reasoning..."}]
    }

    assert {:ok, resp} = Response.parse_response(response)
    assert [%{type: "thinking", text: nil}] = resp.content
  end

  test "parse_response/1 accepts usage without service_tier, since Anthropic doesn't guarantee it" do
    response = %{
      @valid_response
      | "usage" => %{
          "cache_creation_input_tokens" => 0,
          "cache_read_input_tokens" => 0,
          "input_tokens" => 47,
          "output_tokens" => 5
        }
    }

    assert {:ok, resp} = Response.parse_response(response)
    assert resp.usage.service_tier == nil
  end

  test "parse_response/1 still rejects a response with no content blocks at all" do
    response = %{@valid_response | "content" => []}

    assert {:error, changeset} = Response.parse_response(response)
    assert %{content: _} = errors_on(changeset)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
