defmodule Japanese.Games.VisionTest do
  use ExUnit.Case, async: true

  alias Japanese.Games.Vision

  defp symbol(text, break \\ nil) do
    base = %{"text" => text}
    if break, do: Map.put(base, "property", %{"detectedBreak" => %{"type" => break}}), else: base
  end

  defp paragraph(symbols, [{x0, y0}, {x1, y1}]) do
    %{
      "boundingBox" => %{
        "vertices" => [
          %{"x" => x0, "y" => y0},
          %{"x" => x1, "y" => y0},
          %{"x" => x1, "y" => y1},
          %{"y" => y1}
        ]
      },
      "words" => [%{"symbols" => symbols}]
    }
  end

  test "parses paragraphs into boxed lines sorted top to bottom" do
    response = %{
      "responses" => [
        %{
          "fullTextAnnotation" => %{
            "text" => "銅の槍\nLV. 15\n",
            "pages" => [
              %{
                "blocks" => [
                  %{
                    "paragraphs" => [
                      paragraph(
                        [
                          symbol("L"),
                          symbol("V"),
                          symbol(".", "SPACE"),
                          symbol("1"),
                          symbol("5", "EOL_SURE_SPACE")
                        ],
                        [{10, 400}, {60, 420}]
                      ),
                      paragraph([symbol("銅"), symbol("の"), symbol("槍", "LINE_BREAK")], [
                        {100, 30},
                        {180, 52}
                      ])
                    ]
                  }
                ]
              }
            ]
          }
        }
      ]
    }

    assert {:ok, %{text: "銅の槍\nLV. 15\n", lines: [spear, level]}} = Vision.parse(response)
    assert spear == %{text: "銅の槍", x0: 0, x1: 180, y0: 30, y1: 52}
    assert level.text == "LV. 15"

    assert Vision.format_lines([spear]) == "[x=0-180 y=30-52] 銅の槍"
  end

  test "an image without text is an empty success; API errors are errors" do
    assert {:ok, %{text: "", lines: []}} = Vision.parse(%{"responses" => [%{}]})

    assert {:error, {:vision, "bad image"}} =
             Vision.parse(%{"responses" => [%{"error" => %{"message" => "bad image"}}]})
  end
end
