defmodule Japanese.Games.TranscriptTest do
  use ExUnit.Case, async: true

  alias Japanese.Games.Transcript

  @ocr "ITEM\nEQUIP\n銅の槍\n儀式の鎧\nNone\n"

  defp reply(sections, extra \\ %{}) do
    Jason.encode!(
      Map.merge(
        %{"description" => " equipment menu ", "kind" => "menu", "sections" => sections},
        extra
      )
    )
  end

  test "moves English-only lines into labels, keeping focus" do
    json =
      reply([
        %{
          "name" => "main menu",
          "lines" => [
            %{"ja" => "ITEM", "en" => "ITEM"},
            %{"ja" => "EQUIP", "en" => "EQUIP", "focused" => true}
          ]
        },
        %{
          "name" => "equipped",
          "labels" => ["None"],
          "lines" => [%{"ja" => "銅の槍", "reading" => "どうのやり", "en" => "Copper Spear"}]
        }
      ])

    assert {:ok, t} = Transcript.parse(json, @ocr)
    assert t.description == "equipment menu"
    assert t.kind == "menu"

    assert [menu, equipped] = t.sections
    assert menu["lines"] == []
    assert menu["labels"] == ["ITEM", "EQUIP"]
    assert menu["focused_label"] == "EQUIP"
    assert equipped["labels"] == ["None"]
    assert [%{"ja" => "銅の槍", "reading" => "どうのやり"} = line] = equipped["lines"]
    refute Map.has_key?(line, "unverified")
  end

  test "flags Japanese the OCR never saw, unless the model said OCR missed it" do
    json =
      reply([
        %{
          "name" => "text",
          "lines" => [
            %{"ja" => "鋼の槍", "en" => "Steel Spear"},
            %{"ja" => "盾", "en" => "Shield", "ocr_missed" => true}
          ]
        }
      ])

    assert {:ok, %{sections: [%{"lines" => [guessed, missed]}]}} = Transcript.parse(json, @ocr)
    assert guessed["unverified"] == true
    refute Map.has_key?(missed, "unverified")
  end

  test "drops empty sections and unknown keys, tolerates a code fence" do
    json =
      "Here you go:\n```json\n" <>
        reply([
          %{"name" => "empty", "lines" => [%{"ja" => "  "}]},
          %{"lines" => [%{"ja" => "儀式の鎧", "en" => "Ritual Armor", "x" => 1}]}
        ]) <> "\n```"

    assert {:ok, %{sections: [section]}} = Transcript.parse(json, @ocr)
    assert section["name"] == "text"
    assert [line] = section["lines"]
    refute Map.has_key?(line, "x")
  end

  test "rejects a reply without a JSON object" do
    assert {:error, :invalid_transcript} = Transcript.parse("sorry, no", @ocr)
    assert {:error, :invalid_transcript} = Transcript.parse("{not json}", @ocr)
  end
end
