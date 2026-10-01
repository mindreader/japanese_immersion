defmodule Japanese.GamesTest do
  use Japanese.GamesCase, async: false
  use Mimic

  alias Japanese.Games
  alias Japanese.Games.{Processor, Shot, Vision}
  alias Japanese.Translation

  setup :set_mimic_global
  setup :verify_on_exit!

  @ocr %{text: "銅の槍\nEQUIP\n", lines: [%{text: "銅の槍", x0: 0, x1: 10, y0: 0, y1: 10}]}

  @reply Jason.encode!(%{
           "description" => "equipment menu",
           "kind" => "menu",
           "pointer" => "on 銅の槍",
           "sections" => [
             %{
               "name" => "items",
               "lines" => [
                 %{
                   "ja" => "銅の槍",
                   "reading" => "どうのやり",
                   "en" => "Copper Spear",
                   "focused" => true
                 },
                 %{"ja" => "EQUIP", "en" => "EQUIP"}
               ]
             }
           ]
         })

  defp image_file(name \\ "20261001083845_1.jpg") do
    dir = Briefly.create!(directory: true)
    path = Path.join(dir, name)
    File.write!(path, "fake jpeg")
    path
  end

  describe "storage" do
    test "saves, lists newest first and fetches shots", %{games_dir: dir} do
      {:ok, _} = Games.save_shot(Shot.new("deck", "1", "20261001080000_1.jpg", game: "G"))
      {:ok, _} = Games.save_shot(Shot.new("deck", "2", "20261001090000_1.jpg"))

      assert File.exists?(Path.join([dir, "1", "deck-20261001080000_1.json"]))

      assert [%Shot{appid: "2"}, %Shot{appid: "1", taken_at: "2026-10-01 08:00:00"}] =
               Games.list_shots()

      assert {:ok, %Shot{game: "G", status: :pending}} = Games.get_shot("deck-20261001080000_1")
      assert Games.known_game_name("1") == "G"
      assert {:error, :not_found} = Games.get_shot("../etc")
      assert {:error, :invalid_name} = Games.save_shot(Shot.new("deck", "../x", "a.jpg"))
    end

    test "the games directory is not a story" do
      corpus = Briefly.create!(directory: true)
      File.mkdir_p!(Path.join(corpus, "_games/1"))
      File.mkdir_p!(Path.join(corpus, "story"))

      assert {:ok, ["story"]} =
               Japanese.Corpus.StorageLayer.list_stories(%Japanese.Corpus.StorageLayer{
                 working_directory: corpus
               })
    end
  end

  describe "processor" do
    test "a local image is OCRed, transcribed and stored as text only" do
      Games.subscribe()
      Mimic.expect(Vision, :annotate, fn "fake jpeg" -> {:ok, @ocr} end)

      Mimic.expect(Translation, :transcribe_screenshot, fn "fake jpeg", "image/jpeg", ocr_lines ->
        assert ocr_lines =~ "銅の槍"
        {:ok, @reply}
      end)

      assert :ok = Processor.import_file(image_file(), "1718570", game: "ASTLIBRA")
      assert_receive {:shot_added, %Shot{id: "local-20261001083845_1", status: :pending}}
      assert_receive {:shot_updated, %Shot{status: :processing}}
      assert_receive {:shot_updated, %Shot{status: :done} = shot}, 2_000

      assert shot.description == "equipment menu"
      assert [%{"labels" => ["EQUIP"], "lines" => [%{"ja" => "銅の槍"}]}] = shot.sections
      assert {:ok, %Shot{status: :done, game: "ASTLIBRA"}} = Games.get_shot(shot.id)

      # Already recorded: importing again is a no-op.
      assert :ignored = Processor.import_file(image_file(), "1718570")
    end

    test "a failure is recorded and can be retried" do
      Games.subscribe()
      Mimic.expect(Vision, :annotate, fn _ -> {:error, :missing_vision_api_key} end)

      :ok = Processor.import_file(image_file(), "1")

      assert_receive {:shot_updated,
                      %Shot{status: :error, error: "GOOGLE_VISION_API_KEY is not set"} = shot},
                     2_000

      Mimic.expect(Vision, :annotate, fn _ -> {:ok, %{text: "", lines: []}} end)
      assert :ok = Processor.retry(shot.id)

      assert_receive {:shot_updated,
                      %Shot{status: :done, sections: [], description: "no text found"}},
                     2_000
    end
  end
end
