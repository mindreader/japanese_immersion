defmodule Japanese.Games.VisionTest do
  # Not async: one test sets the Vision API key in the application env.
  use ExUnit.Case, async: false
  use Mimic

  setup :verify_on_exit!

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

  test "asks for Connection: close so no connection is kept idle in the pool" do
    previous = Application.get_env(:japanese, Vision)
    Application.put_env(:japanese, Vision, api_key: "test-key")
    on_exit(fn -> Application.put_env(:japanese, Vision, previous || []) end)

    Mimic.expect(Req, :post, fn _url, opts ->
      assert opts[:headers] == [{"connection", "close"}]
      assert opts[:finch] == Japanese.Finch
      {:ok, %Req.Response{status: 200, body: %{"responses" => [%{}]}}}
    end)

    assert {:ok, %{lines: []}} = Vision.annotate("jpeg bytes")
  end
end
