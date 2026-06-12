defmodule Japanese.Drill.ConjugatorTest do
  use ExUnit.Case, async: true

  alias Japanese.Drill.{Conjugator, Verb, Verbs}

  defp verb(kana) do
    Enum.find(Verbs.all(), &(&1.kana == kana)) ||
      raise "no seeded verb with kana #{inspect(kana)}"
  end

  defp conj(kana, form), do: Conjugator.conjugate(verb(kana), form)

  describe "godan past form (covers every row)" do
    test "う row: 買う → 買った", do: assert(conj("かう", :past) == {"買った", "かった"})
    test "く row: 書く → 書いた", do: assert(conj("かく", :past) == {"書いた", "かいた"})
    test "ぐ row: 泳ぐ → 泳いだ", do: assert(conj("およぐ", :past) == {"泳いだ", "およいだ"})
    test "す row: 話す → 話した", do: assert(conj("はなす", :past) == {"話した", "はなした"})
    test "つ row: 待つ → 待った", do: assert(conj("まつ", :past) == {"待った", "まった"})
    test "ぬ row: 死ぬ → 死んだ", do: assert(conj("しぬ", :past) == {"死んだ", "しんだ"})
    test "ぶ row: 遊ぶ → 遊んだ", do: assert(conj("あそぶ", :past) == {"遊んだ", "あそんだ"})
    test "む row: 飲む → 飲んだ", do: assert(conj("のむ", :past) == {"飲んだ", "のんだ"})
    test "る row (godan): 取る → 取った", do: assert(conj("とる", :past) == {"取った", "とった"})
  end

  describe "godan te form (covers every row)" do
    test "う row: 買う → 買って", do: assert(conj("かう", :te) == {"買って", "かって"})
    test "く row: 書く → 書いて", do: assert(conj("かく", :te) == {"書いて", "かいて"})
    test "ぐ row: 泳ぐ → 泳いで", do: assert(conj("およぐ", :te) == {"泳いで", "およいで"})
    test "す row: 話す → 話して", do: assert(conj("はなす", :te) == {"話して", "はなして"})
    test "つ row: 待つ → 待って", do: assert(conj("まつ", :te) == {"待って", "まって"})
    test "ぬ row: 死ぬ → 死んで", do: assert(conj("しぬ", :te) == {"死んで", "しんで"})
    test "ぶ row: 遊ぶ → 遊んで", do: assert(conj("あそぶ", :te) == {"遊んで", "あそんで"})
    test "む row: 飲む → 飲んで", do: assert(conj("のむ", :te) == {"飲んで", "のんで"})
    test "る row (godan): 取る → 取って", do: assert(conj("とる", :te) == {"取って", "とって"})
  end

  describe "godan negative (a-row + ない, with わ for う-verbs)" do
    test "う row uses わ: 買う → 買わない", do: assert(conj("かう", :negative) == {"買わない", "かわない"})
    test "く row: 書く → 書かない", do: assert(conj("かく", :negative) == {"書かない", "かかない"})
    test "す row: 話す → 話さない", do: assert(conj("はなす", :negative) == {"話さない", "はなさない"})
    test "む row: 飲む → 飲まない", do: assert(conj("のむ", :negative) == {"飲まない", "のまない"})
    test "る row: 取る → 取らない", do: assert(conj("とる", :negative) == {"取らない", "とらない"})
  end

  describe "godan other forms" do
    test "polite: 買う → 買います", do: assert(conj("かう", :polite) == {"買います", "かいます"})

    test "polite negative: 書く → 書きません",
      do: assert(conj("かく", :polite_negative) == {"書きません", "かきません"})

    test "polite past: 話す → 話しました",
      do: assert(conj("はなす", :polite_past) == {"話しました", "はなしました"})

    test "potential: 飲む → 飲める", do: assert(conj("のむ", :potential) == {"飲める", "のめる"})
    test "volitional: 買う → 買おう", do: assert(conj("かう", :volitional) == {"買おう", "かおう"})
    test "imperative: 書く → 書け", do: assert(conj("かく", :imperative) == {"書け", "かけ"})

    test "conditional ば: 飲む → 飲めば",
      do: assert(conj("のむ", :conditional_eba) == {"飲めば", "のめば"})

    test "conditional たら: 待つ → 待ったら",
      do: assert(conj("まつ", :conditional_tara) == {"待ったら", "まったら"})

    test "tai: 食べる N/A — see ichidan; 買う → 買いたい",
      do: assert(conj("かう", :tai) == {"買いたい", "かいたい"})

    test "passive (う uses わ): 買う → 買われる",
      do: assert(conj("かう", :passive) == {"買われる", "かわれる"})

    test "causative (う uses わ): 買う → 買わせる",
      do: assert(conj("かう", :causative) == {"買わせる", "かわせる"})

    test "prohibitive: 飲む → 飲むな",
      do: assert(conj("のむ", :prohibitive) == {"飲むな", "のむな"})
  end

  describe "ichidan (食べる)" do
    test "plain", do: assert(conj("たべる", :plain) == {"食べる", "たべる"})
    test "past", do: assert(conj("たべる", :past) == {"食べた", "たべた"})
    test "negative", do: assert(conj("たべる", :negative) == {"食べない", "たべない"})
    test "te", do: assert(conj("たべる", :te) == {"食べて", "たべて"})
    test "polite", do: assert(conj("たべる", :polite) == {"食べます", "たべます"})
    test "imperative (ろ, not え)", do: assert(conj("たべる", :imperative) == {"食べろ", "たべろ"})

    test "volitional (よう, not おう)",
      do: assert(conj("たべる", :volitional) == {"食べよう", "たべよう"})

    test "potential (られる)",
      do: assert(conj("たべる", :potential) == {"食べられる", "たべられる"})

    test "passive (られる)", do: assert(conj("たべる", :passive) == {"食べられる", "たべられる"})
    test "causative (させる)", do: assert(conj("たべる", :causative) == {"食べさせる", "たべさせる"})

    test "conditional ば (れば)",
      do: assert(conj("たべる", :conditional_eba) == {"食べれば", "たべれば"})
  end

  describe "する" do
    test "plain", do: assert(conj("する", :plain) == {"する", "する"})
    test "past", do: assert(conj("する", :past) == {"した", "した"})
    test "negative", do: assert(conj("する", :negative) == {"しない", "しない"})
    test "te", do: assert(conj("する", :te) == {"して", "して"})
    test "polite", do: assert(conj("する", :polite) == {"します", "します"})

    test "potential is できる (not すれる)",
      do: assert(conj("する", :potential) == {"できる", "できる"})

    test "conditional ば is すれば",
      do: assert(conj("する", :conditional_eba) == {"すれば", "すれば"})

    test "imperative is しろ", do: assert(conj("する", :imperative) == {"しろ", "しろ"})
    test "volitional is しよう", do: assert(conj("する", :volitional) == {"しよう", "しよう"})
    test "passive is される", do: assert(conj("する", :passive) == {"される", "される"})
  end

  describe "来る (kana reading shifts く/こ/き)" do
    test "plain", do: assert(conj("くる", :plain) == {"来る", "くる"})
    test "past (き)", do: assert(conj("くる", :past) == {"来た", "きた"})
    test "negative (こ)", do: assert(conj("くる", :negative) == {"来ない", "こない"})
    test "te (き)", do: assert(conj("くる", :te) == {"来て", "きて"})
    test "polite (き)", do: assert(conj("くる", :polite) == {"来ます", "きます"})
    test "imperative (こい)", do: assert(conj("くる", :imperative) == {"来い", "こい"})

    test "volitional (こよう)",
      do: assert(conj("くる", :volitional) == {"来よう", "こよう"})

    test "potential (こられる)",
      do: assert(conj("くる", :potential) == {"来られる", "こられる"})

    test "conditional ば (くれば)",
      do: assert(conj("くる", :conditional_eba) == {"来れば", "くれば"})
  end

  describe "行く (godan く-verb with irregular te/ta)" do
    test "past is 行った (NOT 行いた)", do: assert(conj("いく", :past) == {"行った", "いった"})
    test "te is 行って (NOT 行いて)", do: assert(conj("いく", :te) == {"行って", "いって"})

    test "conditional たら is 行ったら",
      do: assert(conj("いく", :conditional_tara) == {"行ったら", "いったら"})

    test "negative behaves as regular godan",
      do: assert(conj("いく", :negative) == {"行かない", "いかない"})

    test "polite behaves as regular godan",
      do: assert(conj("いく", :polite) == {"行きます", "いきます"})

    test "potential behaves as regular godan: 行ける",
      do: assert(conj("いく", :potential) == {"行ける", "いける"})
  end

  describe "ある (godan る-verb with irregular negative)" do
    test "plain is ある", do: assert(conj("ある", :plain) == {"ある", "ある"})
    test "past is あった", do: assert(conj("ある", :past) == {"あった", "あった"})

    test "negative is ない (NOT あらない)",
      do: assert(conj("ある", :negative) == {"ない", "ない"})

    test "past negative is なかった (NOT あらなかった)",
      do: assert(conj("ある", :past_negative) == {"なかった", "なかった"})

    test "polite is あります", do: assert(conj("ある", :polite) == {"あります", "あります"})

    test "conditional ば is あれば",
      do: assert(conj("ある", :conditional_eba) == {"あれば", "あれば"})
  end

  describe "te_iru and friends (progressive / state)" do
    test "ichidan: 食べる → 食べている",
      do: assert(conj("たべる", :te_iru) == {"食べている", "たべている"})

    test "godan む: 飲む → 飲んでいる",
      do: assert(conj("のむ", :te_iru) == {"飲んでいる", "のんでいる"})

    test "godan ぐ: 泳ぐ → 泳いでいる",
      do: assert(conj("およぐ", :te_iru) == {"泳いでいる", "およいでいる"})

    test "iku: 行く → 行っている (uses iku's irregular te form)",
      do: assert(conj("いく", :te_iru) == {"行っている", "いっている"})

    test "te_iru_past: 食べる → 食べていた",
      do: assert(conj("たべる", :te_iru_past) == {"食べていた", "たべていた"})

    test "te_iru_negative: 食べる → 食べていない",
      do: assert(conj("たべる", :te_iru_negative) == {"食べていない", "たべていない"})

    test "te_imasu: 食べる → 食べています",
      do: assert(conj("たべる", :te_imasu) == {"食べています", "たべています"})

    test "te_imasen: 食べる → 食べていません",
      do: assert(conj("たべる", :te_imasen) == {"食べていません", "たべていません"})
  end

  describe "passive_past / passive_polite" do
    test "ichidan passive_past: 食べる → 食べられた",
      do: assert(conj("たべる", :passive_past) == {"食べられた", "たべられた"})

    test "godan passive_past (う uses わ): 買う → 買われた",
      do: assert(conj("かう", :passive_past) == {"買われた", "かわれた"})

    test "godan passive_past: 飲む → 飲まれた",
      do: assert(conj("のむ", :passive_past) == {"飲まれた", "のまれた"})

    test "passive_polite: 食べる → 食べられます",
      do: assert(conj("たべる", :passive_polite) == {"食べられます", "たべられます"})
  end

  describe "causative_past" do
    test "ichidan: 食べる → 食べさせた",
      do: assert(conj("たべる", :causative_past) == {"食べさせた", "たべさせた"})

    test "godan む: 飲む → 飲ませた",
      do: assert(conj("のむ", :causative_past) == {"飲ませた", "のませた"})
  end

  describe "causative_passive (godan non-す contracts; everything else uses full form)" do
    test "godan む uses contracted form: 飲む → 飲まされる (NOT 飲ませられる)",
      do: assert(conj("のむ", :causative_passive) == {"飲まされる", "のまされる"})

    test "godan う uses contracted form with わ: 買う → 買わされる",
      do: assert(conj("かう", :causative_passive) == {"買わされる", "かわされる"})

    test "godan く contracted: 書く → 書かされる",
      do: assert(conj("かく", :causative_passive) == {"書かされる", "かかされる"})

    test "iku contracted: 行く → 行かされる",
      do: assert(conj("いく", :causative_passive) == {"行かされる", "いかされる"})

    test "godan す uses FULL form (no double-さ contraction): 話す → 話させられる",
      do: assert(conj("はなす", :causative_passive) == {"話させられる", "はなさせられる"})

    test "ichidan uses full form: 食べる → 食べさせられる",
      do: assert(conj("たべる", :causative_passive) == {"食べさせられる", "たべさせられる"})

    test "suru: する → させられる",
      do: assert(conj("する", :causative_passive) == {"させられる", "させられる"})

    test "kuru: 来る → 来させられる",
      do: assert(conj("くる", :causative_passive) == {"来させられる", "こさせられる"})
  end

  describe "causative_passive_past" do
    test "godan contracted past: 飲む → 飲まされた",
      do: assert(conj("のむ", :causative_passive_past) == {"飲まされた", "のまされた"})

    test "ichidan past: 食べる → 食べさせられた",
      do: assert(conj("たべる", :causative_passive_past) == {"食べさせられた", "たべさせられた"})
  end

  describe "te_shimau and te_shimatta" do
    test "ichidan: 食べる → 食べてしまう",
      do: assert(conj("たべる", :te_shimau) == {"食べてしまう", "たべてしまう"})

    test "godan む: 飲む → 飲んでしまう",
      do: assert(conj("のむ", :te_shimau) == {"飲んでしまう", "のんでしまう"})

    test "te_shimatta with iku's irregular te: 行く → 行ってしまった",
      do: assert(conj("いく", :te_shimatta) == {"行ってしまった", "いってしまった"})

    test "te_shimatta: 忘れる-style, here 食べる → 食べてしまった",
      do: assert(conj("たべる", :te_shimatta) == {"食べてしまった", "たべてしまった"})
  end

  test "forms/0 lists every supported conjugation atom" do
    assert :plain in Conjugator.forms()
    assert :past in Conjugator.forms()
    assert :prohibitive in Conjugator.forms()
    assert :te_iru in Conjugator.forms()
    assert :causative_passive in Conjugator.forms()
    assert :te_shimatta in Conjugator.forms()
  end

  test "label/1 returns a human-readable string for every form" do
    for f <- Conjugator.forms() do
      assert is_binary(Conjugator.label(f))
    end
  end

  test "help/1 returns label + description + example for every form" do
    for f <- Conjugator.forms() do
      h = Conjugator.help(f)
      assert is_binary(h.label)
      assert is_binary(h.description) and String.length(h.description) > 10
      assert is_binary(h.example) and String.length(h.example) > 5
    end
  end

  test "conjugating every verb × every form does not crash" do
    for v <- Verbs.all(), f <- Conjugator.forms() do
      assert {_kanji, _kana} = Conjugator.conjugate(v, f)
    end
  end

  test "suru_compound class works for 勉強する" do
    benkyou_suru = %Verb{
      kanji: "勉強する",
      kana: "べんきょうする",
      english: "to study",
      class: :suru_compound
    }

    assert Conjugator.conjugate(benkyou_suru, :past) == {"勉強した", "べんきょうした"}
    assert Conjugator.conjugate(benkyou_suru, :negative) == {"勉強しない", "べんきょうしない"}
    assert Conjugator.conjugate(benkyou_suru, :polite) == {"勉強します", "べんきょうします"}
    assert Conjugator.conjugate(benkyou_suru, :te_iru) == {"勉強している", "べんきょうしている"}
    assert Conjugator.conjugate(benkyou_suru, :potential) == {"勉強できる", "べんきょうできる"}
  end

  ## ─── Weird verbs: explicit manual coverage ──────────────────────────────
  #
  # These describe blocks cover verbs the conjugator is most likely to get
  # wrong, either because they're irregular or because their kana ending
  # would mislead a naive (kana-only) classifier into the wrong verb class.

  describe "weird verb: 死ぬ (only common ぬ-row godan)" do
    test "past: 死んだ", do: assert(conj("しぬ", :past) == {"死んだ", "しんだ"})
    test "te: 死んで", do: assert(conj("しぬ", :te) == {"死んで", "しんで"})
    test "negative: 死なない", do: assert(conj("しぬ", :negative) == {"死なない", "しなない"})

    test "past negative: 死ななかった",
      do: assert(conj("しぬ", :past_negative) == {"死ななかった", "しななかった"})

    test "polite: 死にます", do: assert(conj("しぬ", :polite) == {"死にます", "しにます"})
    test "potential: 死ねる", do: assert(conj("しぬ", :potential) == {"死ねる", "しねる"})

    test "te_iru: 死んでいる (canonical example of state, not progressive)",
      do: assert(conj("しぬ", :te_iru) == {"死んでいる", "しんでいる"})

    test "passive past: 死なれた (suffering passive — 'someone died on me')",
      do: assert(conj("しぬ", :passive_past) == {"死なれた", "しなれた"})

    test "causative: 死なせる",
      do: assert(conj("しぬ", :causative) == {"死なせる", "しなせる"})

    test "imperative: 死ね (notoriously rude)",
      do: assert(conj("しぬ", :imperative) == {"死ね", "しね"})

    test "volitional: 死のう", do: assert(conj("しぬ", :volitional) == {"死のう", "しのう"})

    test "conditional eba: 死ねば",
      do: assert(conj("しぬ", :conditional_eba) == {"死ねば", "しねば"})
  end

  describe "weird verb: する (fully irregular)" do
    test "negative: しない", do: assert(conj("する", :negative) == {"しない", "しない"})

    test "polite negative: しません",
      do: assert(conj("する", :polite_negative) == {"しません", "しません"})

    test "past negative: しなかった",
      do: assert(conj("する", :past_negative) == {"しなかった", "しなかった"})

    test "polite past: しました",
      do: assert(conj("する", :polite_past) == {"しました", "しました"})

    test "polite past negative: しませんでした",
      do: assert(conj("する", :polite_past_negative) == {"しませんでした", "しませんでした"})

    test "tai: したい", do: assert(conj("する", :tai) == {"したい", "したい"})

    test "conditional tara: したら",
      do: assert(conj("する", :conditional_tara) == {"したら", "したら"})

    test "polite imperative: しなさい",
      do: assert(conj("する", :polite_imperative) == {"しなさい", "しなさい"})

    test "prohibitive: するな",
      do: assert(conj("する", :prohibitive) == {"するな", "するな"})

    test "causative: させる", do: assert(conj("する", :causative) == {"させる", "させる"})

    test "te_iru: している (very common)",
      do: assert(conj("する", :te_iru) == {"している", "している"})

    test "passive past: された",
      do: assert(conj("する", :passive_past) == {"された", "された"})

    test "te_shimatta: してしまった",
      do: assert(conj("する", :te_shimatta) == {"してしまった", "してしまった"})
  end

  describe "weird verb: 切る vs 着る (same kana, different class)" do
    # 切る (godan, to cut) and 着る (ichidan, to wear) both read as きる.
    # They diverge at the first conjugation that distinguishes the classes.
    test "切る past is 切った (godan)", do: assert(conj("きる", :past) == {"切った", "きった"})

    test "着る past is 着た (ichidan)" do
      kiru_wear = Enum.find(Verbs.all(), &(&1.kanji == "着る"))
      assert Conjugator.conjugate(kiru_wear, :past) == {"着た", "きた"}
    end

    test "切る negative is 切らない (godan a-row + ない)",
      do: assert(conj("きる", :negative) == {"切らない", "きらない"})

    test "着る negative is 着ない (ichidan stem + ない)" do
      kiru_wear = Enum.find(Verbs.all(), &(&1.kanji == "着る"))
      assert Conjugator.conjugate(kiru_wear, :negative) == {"着ない", "きない"}
    end

    test "切る te is 切って (godan)", do: assert(conj("きる", :te) == {"切って", "きって"})

    test "着る te is 着て (ichidan)" do
      kiru_wear = Enum.find(Verbs.all(), &(&1.kanji == "着る"))
      assert Conjugator.conjugate(kiru_wear, :te) == {"着て", "きて"}
    end
  end

  describe "weird verb: 帰る vs 変える (look-alike kaeru pair)" do
    # Verbs.all() has both 帰る (godan, return home) and 変える (ichidan, change).
    # かえる kana alone is ambiguous — class field disambiguates.
    test "帰る (godan) past is 帰った" do
      kaeru_return = Enum.find(Verbs.all(), &(&1.kanji == "帰る"))
      assert Conjugator.conjugate(kaeru_return, :past) == {"帰った", "かえった"}
    end

    test "変える (ichidan) past is 変えた" do
      kaeru_change = Enum.find(Verbs.all(), &(&1.kanji == "変える"))
      assert Conjugator.conjugate(kaeru_change, :past) == {"変えた", "かえた"}
    end
  end

  describe "weird verb: godan -iru verbs that look like ichidan" do
    # If misclassified as ichidan these would produce 知た, 走た, 入た, etc.
    test "知る past is 知った (godan)", do: assert(conj("しる", :past) == {"知った", "しった"})

    test "走る past is 走った (godan)",
      do: assert(conj("はしる", :past) == {"走った", "はしった"})

    test "入る past is 入った (godan)",
      do: assert(conj("はいる", :past) == {"入った", "はいった"})

    test "知る negative is 知らない (godan)",
      do: assert(conj("しる", :negative) == {"知らない", "しらない"})
  end
end
