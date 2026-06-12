defmodule Japanese.Drill.Conjugator do
  @moduledoc """
  Pure conjugation functions for the drill mode.

  Every public function returns `{kanji_form, kana_form}`. Drill prompts use
  the kana form; reveal shows the kanji form alongside.

  Godan endings are derived from the final mora of the dictionary form (the
  table at `@godan_table`). Ichidan drops the trailing る. The four irregulars
  (する, 来る, 行く, ある) are handled as special cases — `iku` and `aru` fall
  back to the godan path for the forms they share with regular godan verbs.
  """

  alias Japanese.Drill.Verb

  # Each entry: short label (always shown), description (English meaning),
  # example (one short worked example).
  @forms_meta [
    # Basic forms
    plain: %{
      label: "dictionary",
      description:
        "Dictionary form. Plain present/future affirmative — what an action will/does happen.",
      example: "毎日寿司を食べる — I eat sushi every day."
    },
    past: %{
      label: "past",
      description: "Past tense — \"did\" or \"have done\".",
      example: "昨日寿司を食べた — I ate sushi yesterday."
    },
    negative: %{
      label: "negative",
      description: "Plain negative present — \"do not do\".",
      example: "寿司を食べない — I don't eat sushi."
    },
    past_negative: %{
      label: "past negative",
      description: "Plain negative past — \"did not do\".",
      example: "昨日は食べなかった — I didn't eat yesterday."
    },
    te: %{
      label: "te form",
      description:
        "Te form. Connects clauses (\"and then\"), forms requests with ください, " <>
          "and combines with auxiliaries like いる / ある / しまう / おく.",
      example: "食べて寝る — I eat and (then) sleep."
    },
    polite: %{
      label: "polite (〜ます)",
      description: "Polite affirmative — same meaning as the plain form, used in polite speech.",
      example: "寿司を食べます — I eat sushi."
    },
    polite_negative: %{
      label: "polite negative",
      description: "Polite negative — \"do not do\" in polite speech.",
      example: "お酒を飲みません — I don't drink alcohol."
    },
    polite_past: %{
      label: "polite past",
      description: "Polite past — \"did\" in polite speech.",
      example: "もう食べました — I already ate."
    },
    polite_past_negative: %{
      label: "polite past negative",
      description: "Polite negative past — \"did not do\" in polite speech.",
      example: "昨日は行きませんでした — I didn't go yesterday."
    },
    volitional: %{
      label: "volitional",
      description:
        "\"Let's do\" or \"I think I will\". Used for invitations, intentions, suggestions.",
      example: "食べよう — Let's eat."
    },
    imperative: %{
      label: "imperative",
      description:
        "Blunt command. Rude in most contexts — drill sergeants, angry parents, anime characters.",
      example: "早く食べろ! — Eat it quickly!"
    },
    polite_imperative: %{
      label: "polite imperative (〜なさい)",
      description:
        "Soft command. Gentler than the plain imperative — what parents and teachers use.",
      example: "野菜を食べなさい — Eat your vegetables."
    },
    tai: %{
      label: "〜たい (want to)",
      description:
        "\"Want to do\" — expresses the speaker's desire. Conjugates further like an い-adjective.",
      example: "寿司が食べたい — I want to eat sushi."
    },
    conditional_eba: %{
      label: "conditional 〜ば",
      description:
        "\"If [X], then [Y]\" — emphasizes a general or hypothetical condition. " <>
          "More abstract than 〜たら.",
      example: "食べれば元気になる — If you eat, you'll feel better."
    },
    conditional_tara: %{
      label: "conditional 〜たら",
      description:
        "\"When/if [X], then [Y]\" — colloquial, often \"after doing\". " <>
          "More concrete than 〜ば.",
      example: "食べたら出かけよう — Once we eat, let's go out."
    },
    potential: %{
      label: "potential",
      description:
        "\"Can do\" / \"is able to\". For ichidan and 来る, identical to the passive — context disambiguates.",
      example: "寿司が食べられる — I can eat sushi."
    },
    passive: %{
      label: "passive",
      description:
        "\"Is done to\". In Japanese, very often a \"suffering passive\" — something was done that affected the speaker, " <>
          "often unpleasantly.",
      example: "雨に降られた — I got rained on."
    },
    causative: %{
      label: "causative",
      description:
        "\"Make/let someone do\". Context decides between \"make\" (forced) and \"let\" (permitted).",
      example: "子供に野菜を食べさせる — I make/let the child eat vegetables."
    },
    prohibitive: %{
      label: "prohibitive (〜な)",
      description:
        "Strong negative command — \"don't do that\". Blunt; same register as the imperative.",
      example: "食べるな! — Don't eat it!"
    },

    # Compound forms
    te_iru: %{
      label: "〜ている (progressive / state)",
      description:
        "Te form + いる. Either \"is currently doing\" (for action verbs) or \"is in the state of having done\" " <>
          "(for change-of-state verbs like 死ぬ, 結婚する). Context tells which.",
      example: "食べている — is eating  /  死んでいる — is dead (state)."
    },
    te_iru_past: %{
      label: "〜ていた (past progressive / past state)",
      description: "Te form + いた. \"Was doing\" or \"had been in the state of\".",
      example: "寝ていた — was sleeping."
    },
    te_iru_negative: %{
      label: "〜ていない (not yet / not currently)",
      description:
        "Te form + いない. \"Is not currently doing\" or, very often, \"has not done yet\".",
      example: "まだ食べていない — I haven't eaten yet."
    },
    te_imasu: %{
      label: "〜ています (polite progressive)",
      description: "Polite version of 〜ている.",
      example: "今食べています — I'm eating right now."
    },
    te_imasen: %{
      label: "〜ていません (polite not yet)",
      description: "Polite version of 〜ていない.",
      example: "まだ食べていません — I haven't eaten yet."
    },
    passive_past: %{
      label: "passive past",
      description: "Past tense of the passive — \"was/were done to\". Very common in narrative.",
      example: "財布を盗まれた — My wallet was stolen (on me)."
    },
    passive_polite: %{
      label: "passive polite",
      description: "Polite version of the passive.",
      example: "大切にされます — Is treated with care."
    },
    causative_past: %{
      label: "causative past",
      description: "Past tense of the causative — \"made/let someone do\" in the past.",
      example: "子供に野菜を食べさせた — I made the child eat vegetables."
    },
    causative_passive: %{
      label: "causative-passive",
      description:
        "\"Was made to do (unwillingly)\". Carries a put-upon feeling — you didn't want to but " <>
          "someone made you. Godan u-verbs use the contracted form (〜まされる, 〜かされる).",
      example: "飲み会で飲まされる — I get made to drink at work parties."
    },
    causative_passive_past: %{
      label: "causative-passive past",
      description: "Past tense of causative-passive — \"was made to do (and didn't want to)\".",
      example: "嫌いな野菜を食べさせられた — I was made to eat vegetables I hate."
    },
    te_shimau: %{
      label: "〜てしまう (completion / regret)",
      description:
        "Te form + しまう. \"End up doing\" / \"do completely, often regretfully\". " <>
          "Casually contracts to 〜ちゃう / 〜じゃう.",
      example: "全部食べてしまう — I'm going to eat it all up."
    },
    te_shimatta: %{
      label: "〜てしまった (ended up doing)",
      description:
        "Past of 〜てしまう. \"Did it (and oh no)\" — extremely common for mistakes and unintended completions.",
      example: "忘れてしまった — I (totally) forgot."
    }
  ]

  @spec forms() :: [atom()]
  def forms, do: Keyword.keys(@forms_meta)

  @spec label(atom()) :: String.t()
  def label(form), do: Keyword.fetch!(@forms_meta, form).label

  @spec help(atom()) :: %{label: String.t(), description: String.t(), example: String.t()}
  def help(form), do: Keyword.fetch!(@forms_meta, form)

  ## Auxiliary verbs used by compound forms.
  # いる is conventionally written in kana in ~ている.
  @iru_aux %Verb{kanji: nil, kana: "いる", english: "to be (animate)", class: :ichidan}
  # しまう likewise.
  @shimau_aux %Verb{
    kanji: nil,
    kana: "しまう",
    english: "to finish / put away",
    class: :godan
  }

  # Godan endings: {a_row, i_row, e_row, o_row, ta_ending, te_ending}.
  # Defined here (rather than nearer the godan/2 function) because
  # causative_passive/1 references it for the contracted godan form.
  @godan_table %{
    "う" => {"わ", "い", "え", "お", "った", "って"},
    "く" => {"か", "き", "け", "こ", "いた", "いて"},
    "ぐ" => {"が", "ぎ", "げ", "ご", "いだ", "いで"},
    "す" => {"さ", "し", "せ", "そ", "した", "して"},
    "つ" => {"た", "ち", "て", "と", "った", "って"},
    "ぬ" => {"な", "に", "ね", "の", "んだ", "んで"},
    "ぶ" => {"ば", "び", "べ", "ぼ", "んだ", "んで"},
    "む" => {"ま", "み", "め", "も", "んだ", "んで"},
    "る" => {"ら", "り", "れ", "ろ", "った", "って"}
  }

  @spec conjugate(Verb.t(), atom()) :: {String.t(), String.t()}
  # Compound forms — dispatched before class so they work for any verb class.
  def conjugate(v, :te_iru), do: te_aux(v, @iru_aux, :plain)
  def conjugate(v, :te_iru_past), do: te_aux(v, @iru_aux, :past)
  def conjugate(v, :te_iru_negative), do: te_aux(v, @iru_aux, :negative)
  def conjugate(v, :te_imasu), do: te_aux(v, @iru_aux, :polite)
  def conjugate(v, :te_imasen), do: te_aux(v, @iru_aux, :polite_negative)
  def conjugate(v, :te_shimau), do: te_aux(v, @shimau_aux, :plain)
  def conjugate(v, :te_shimatta), do: te_aux(v, @shimau_aux, :past)
  def conjugate(v, :passive_past), do: derived_ichidan(conjugate(v, :passive)) |> conjugate(:past)

  def conjugate(v, :passive_polite),
    do: derived_ichidan(conjugate(v, :passive)) |> conjugate(:polite)

  def conjugate(v, :causative_past),
    do: derived_ichidan(conjugate(v, :causative)) |> conjugate(:past)

  def conjugate(v, :causative_passive), do: causative_passive(v)

  def conjugate(v, :causative_passive_past),
    do: derived_ichidan(conjugate(v, :causative_passive)) |> conjugate(:past)

  # Basic forms — dispatch by class.
  def conjugate(%Verb{class: :godan} = v, form), do: godan(v, form)
  def conjugate(%Verb{class: :ichidan} = v, form), do: ichidan(v, form)
  def conjugate(%Verb{class: :suru}, form), do: suru(form)
  def conjugate(%Verb{class: :kuru}, form), do: kuru(form)
  def conjugate(%Verb{class: :iku} = v, form), do: iku(v, form)
  def conjugate(%Verb{class: :aru} = v, form), do: aru(v, form)
  def conjugate(%Verb{class: :suru_compound} = v, form), do: suru_compound(v, form)

  ## Compound helpers

  # te + auxiliary verb; the auxiliary itself is conjugated to sub_form.
  defp te_aux(verb, aux, sub_form) do
    {tk, th} = conjugate(verb, :te)
    {ak, ah} = conjugate(aux, sub_form)
    {tk <> ak, th <> ah}
  end

  # The result of passive/causative is an ichidan-shape verb (ends in る), so
  # wrap it as one and we can re-conjugate using the existing ichidan logic.
  defp derived_ichidan({kanji, kana}) do
    %Verb{kanji: kanji, kana: kana, english: "", class: :ichidan}
  end

  # Godan-like non-す verbs contract: 飲ませる + られる → 飲まされる (a-row + される).
  # Includes :godan, :iku, :aru since they all behave as godan for this purpose.
  # Godan す-row verbs and everything else use the full form: causative → passive.
  defp causative_passive(%Verb{class: c, kana: kana, kanji: kanji} = v)
       when c in [:godan, :iku, :aru] do
    {kana_stem, final} = split_last(kana)

    if final == "す" do
      derived_ichidan(conjugate(v, :causative)) |> conjugate(:passive)
    else
      kanji_stem = strip_last_grapheme(kanji || kana)
      {a, _, _, _, _, _} = Map.fetch!(@godan_table, final)
      ending = a <> "される"
      {kanji_stem <> ending, kana_stem <> ending}
    end
  end

  defp causative_passive(verb) do
    derived_ichidan(conjugate(verb, :causative)) |> conjugate(:passive)
  end

  ## Godan

  defp godan(%Verb{kana: kana, kanji: kanji}, form) do
    {kana_stem, final} = split_last(kana)
    kanji_stem = strip_last_grapheme(kanji || kana)
    {a, i, e, o, ta, te} = Map.fetch!(@godan_table, final)

    ending =
      case form do
        :plain -> final
        :past -> ta
        :negative -> a <> "ない"
        :past_negative -> a <> "なかった"
        :te -> te
        :polite -> i <> "ます"
        :polite_negative -> i <> "ません"
        :polite_past -> i <> "ました"
        :polite_past_negative -> i <> "ませんでした"
        :volitional -> o <> "う"
        :imperative -> e
        :polite_imperative -> i <> "なさい"
        :tai -> i <> "たい"
        :conditional_eba -> e <> "ば"
        :conditional_tara -> ta <> "ら"
        :potential -> e <> "る"
        :passive -> a <> "れる"
        :causative -> a <> "せる"
        :prohibitive -> final <> "な"
      end

    {kanji_stem <> ending, kana_stem <> ending}
  end

  ## Ichidan

  defp ichidan(%Verb{kana: kana, kanji: kanji}, form) do
    kana_stem = strip_last_grapheme(kana)
    kanji_stem = strip_last_grapheme(kanji || kana)

    ending =
      case form do
        :plain -> "る"
        :past -> "た"
        :negative -> "ない"
        :past_negative -> "なかった"
        :te -> "て"
        :polite -> "ます"
        :polite_negative -> "ません"
        :polite_past -> "ました"
        :polite_past_negative -> "ませんでした"
        :volitional -> "よう"
        :imperative -> "ろ"
        :polite_imperative -> "なさい"
        :tai -> "たい"
        :conditional_eba -> "れば"
        :conditional_tara -> "たら"
        :potential -> "られる"
        :passive -> "られる"
        :causative -> "させる"
        :prohibitive -> "るな"
      end

    {kanji_stem <> ending, kana_stem <> ending}
  end

  ## する

  @suru_table %{
    plain: "する",
    past: "した",
    negative: "しない",
    past_negative: "しなかった",
    te: "して",
    polite: "します",
    polite_negative: "しません",
    polite_past: "しました",
    polite_past_negative: "しませんでした",
    volitional: "しよう",
    imperative: "しろ",
    polite_imperative: "しなさい",
    tai: "したい",
    conditional_eba: "すれば",
    conditional_tara: "したら",
    potential: "できる",
    passive: "される",
    causative: "させる",
    prohibitive: "するな"
  }

  defp suru(form) do
    s = Map.fetch!(@suru_table, form)
    {s, s}
  end

  defp suru_compound(%Verb{kanji: kanji, kana: kana}, form) do
    suffix = Map.fetch!(@suru_table, form)
    prefix_kanji = String.replace_suffix(kanji || kana, "する", "")
    prefix_kana = String.replace_suffix(kana, "する", "")
    {prefix_kanji <> suffix, prefix_kana <> suffix}
  end

  ## 来る

  @kuru_table %{
    plain: {"来る", "くる"},
    past: {"来た", "きた"},
    negative: {"来ない", "こない"},
    past_negative: {"来なかった", "こなかった"},
    te: {"来て", "きて"},
    polite: {"来ます", "きます"},
    polite_negative: {"来ません", "きません"},
    polite_past: {"来ました", "きました"},
    polite_past_negative: {"来ませんでした", "きませんでした"},
    volitional: {"来よう", "こよう"},
    imperative: {"来い", "こい"},
    polite_imperative: {"来なさい", "きなさい"},
    tai: {"来たい", "きたい"},
    conditional_eba: {"来れば", "くれば"},
    conditional_tara: {"来たら", "きたら"},
    potential: {"来られる", "こられる"},
    passive: {"来られる", "こられる"},
    causative: {"来させる", "こさせる"},
    prohibitive: {"来るな", "くるな"}
  }

  defp kuru(form), do: Map.fetch!(@kuru_table, form)

  ## 行く — godan く-verb except te/ta forms become って/った (not いて/いた)

  defp iku(_v, :past), do: {"行った", "いった"}
  defp iku(_v, :te), do: {"行って", "いって"}
  defp iku(_v, :conditional_tara), do: {"行ったら", "いったら"}
  defp iku(v, form), do: godan(v, form)

  ## ある — godan る-verb except negative/past-negative are ない/なかった

  defp aru(_v, :negative), do: {"ない", "ない"}
  defp aru(_v, :past_negative), do: {"なかった", "なかった"}
  defp aru(v, form), do: godan(v, form)

  ## Helpers

  defp split_last(s) do
    graphemes = String.graphemes(s)
    {graphemes |> Enum.drop(-1) |> Enum.join(""), List.last(graphemes)}
  end

  defp strip_last_grapheme(s) do
    s |> String.graphemes() |> Enum.drop(-1) |> Enum.join("")
  end
end
