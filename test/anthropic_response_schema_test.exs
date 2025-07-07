defmodule AnthropicResponseSchemaTest do
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
end
