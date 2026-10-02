defmodule Japanese.Games.Vision do
  @moduledoc """
  Google Cloud Vision OCR (`DOCUMENT_TEXT_DETECTION`) for game screenshots.

  Authenticates with an API key restricted to the Vision API, read from
  `config :japanese, Japanese.Games.Vision, api_key: ...` (the
  `GOOGLE_VISION_API_KEY` environment variable at runtime).

  Vision is the authority on which characters are on screen; Claude only
  arranges and explains them (see `Japanese.Games.Pipeline`).
  """

  @endpoint "https://vision.googleapis.com/v1/images:annotate"

  @type line :: %{text: String.t(), x0: integer(), x1: integer(), y0: integer(), y1: integer()}
  @type result :: %{text: String.t(), lines: [line()]}

  @doc """
  OCRs an image. Returns the full text and one entry per detected paragraph
  with its pixel box, sorted top to bottom, then left to right.
  """
  @spec annotate(binary()) :: {:ok, result()} | {:error, term()}
  def annotate(image) when is_binary(image) do
    with {:ok, key} <- api_key(),
         {:ok, response} <- request(image, key) do
      parse(response)
    end
  end

  @doc """
  Turns a decoded Vision `images:annotate` response body into text + lines.
  An image with no text is a success with an empty result.
  """
  @spec parse(map()) :: {:ok, result()} | {:error, term()}
  def parse(%{"responses" => [%{"error" => %{"message" => message}} | _]}),
    do: {:error, {:vision, message}}

  def parse(%{"responses" => [%{"fullTextAnnotation" => annotation} | _]}) do
    lines =
      for page <- List.wrap(annotation["pages"]),
          block <- List.wrap(page["blocks"]),
          paragraph <- List.wrap(block["paragraphs"]),
          text = paragraph_text(paragraph),
          text != "" do
        Map.put(box(paragraph["boundingBox"]), :text, text)
      end
      |> Enum.sort_by(&{&1.y0, &1.x0})

    {:ok, %{text: annotation["text"] || "", lines: lines}}
  end

  def parse(%{"responses" => [_ | _]}), do: {:ok, %{text: "", lines: []}}
  def parse(other), do: {:error, {:vision_unexpected, other}}

  @doc """
  Formats OCR lines for the model, one per line: `[x=10-200 y=30-52] text`.
  """
  @spec format_lines([line()]) :: String.t()
  def format_lines(lines) do
    Enum.map_join(lines, "\n", fn l -> "[x=#{l.x0}-#{l.x1} y=#{l.y0}-#{l.y1}] #{l.text}" end)
  end

  defp request(image, key) do
    body = %{
      requests: [
        %{
          image: %{content: Base.encode64(image)},
          features: [%{type: "DOCUMENT_TEXT_DETECTION"}],
          imageContext: %{languageHints: ["ja", "en"]}
        }
      ]
    }

    case Req.post(@endpoint,
           params: [key: key],
           json: body,
           finch: Japanese.Finch,
           # One connection per call, never pooled: see Japanese.HTTP.
           headers: Japanese.HTTP.no_keepalive_headers(),
           receive_timeout: 60_000,
           retry: :transient,
           max_retries: 2
         ) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:vision_http, status, error_message(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp api_key do
    case Application.get_env(:japanese, __MODULE__, [])[:api_key] do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_vision_api_key}
    end
  end

  defp error_message(%{"error" => %{"message" => message}}), do: message
  defp error_message(body), do: inspect(body, limit: 20)

  # Vision marks where a space or line break follows a symbol; keep spaces
  # (they matter between English words) and turn breaks into spaces too,
  # since a paragraph is presented as one line.
  defp paragraph_text(paragraph) do
    for word <- List.wrap(paragraph["words"]),
        symbol <- List.wrap(word["symbols"]),
        into: "" do
      break = get_in(symbol, ["property", "detectedBreak", "type"])
      symbol["text"] <> if(break in ["SPACE", "SURE_SPACE", "EOL_SURE_SPACE"], do: " ", else: "")
    end
    |> String.trim()
  end

  defp box(%{"vertices" => vertices}) when is_list(vertices) do
    xs = Enum.map(vertices, &Map.get(&1, "x", 0))
    ys = Enum.map(vertices, &Map.get(&1, "y", 0))
    %{x0: Enum.min(xs), x1: Enum.max(xs), y0: Enum.min(ys), y1: Enum.max(ys)}
  end

  defp box(_), do: %{x0: 0, x1: 0, y0: 0, y1: 0}
end
