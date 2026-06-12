defmodule Japanese.Drill.Verbs do
  @moduledoc """
  Verb list for the drill mode — generated from JPDB frequency rankings
  joined with JMDict-common POS information. Re-generate with
  `priv/drill/gen_verbs.py`.

  Ordered by JPDB frequency rank ascending. The `frequency` field is
  the JPDB rank — lower numbers mean more common.

  Class is stored explicitly because kana endings alone can't
  distinguish godan 切る (kiru, to cut) from ichidan 着る (kiru, to
  wear). Edit freely — this file is hand-committed.
  """

  alias Japanese.Drill.Verb

  @verbs [
    %Verb{kanji: nil, kana: "する", english: "to do", class: :suru, frequency: 13},
    %Verb{
      kanji: nil,
      kana: "いる",
      english: "to be (of animate objects)",
      class: :ichidan,
      frequency: 21
    },
    %Verb{kanji: nil, kana: "よる", english: "to be due to", class: :godan, frequency: 125},
    %Verb{kanji: "出る", kana: "でる", english: "to leave", class: :ichidan, frequency: 167},
    %Verb{kanji: "行う", kana: "おこなう", english: "to perform", class: :godan, frequency: 188},
    %Verb{kanji: "受ける", kana: "うける", english: "to receive", class: :ichidan, frequency: 252},
    %Verb{kanji: "思う", kana: "おもう", english: "to think", class: :godan, frequency: 283},
    %Verb{
      kanji: "示す",
      kana: "しめす",
      english: "to (take out and) show",
      class: :godan,
      frequency: 293
    },
    %Verb{kanji: "入る", kana: "はいる", english: "to enter", class: :godan, frequency: 310},
    %Verb{kanji: "決める", kana: "きめる", english: "to decide", class: :ichidan, frequency: 342},
    %Verb{kanji: "見る", kana: "みる", english: "to see", class: :ichidan, frequency: 353},
    %Verb{kanji: "求める", kana: "もとめる", english: "to want", class: :ichidan, frequency: 355},
    %Verb{kanji: "言う", kana: "いう", english: "to say", class: :godan, frequency: 400},
    %Verb{
      kanji: "持つ",
      kana: "もつ",
      english: "to hold (in one's hand)",
      class: :godan,
      frequency: 427
    },
    %Verb{kanji: "述べる", kana: "のべる", english: "to state", class: :ichidan, frequency: 434},
    %Verb{kanji: "話す", kana: "はなす", english: "to talk", class: :godan, frequency: 470},
    %Verb{
      kanji: "考える",
      kana: "かんがえる",
      english: "to think (about, of)",
      class: :ichidan,
      frequency: 477
    },
    %Verb{kanji: "続く", kana: "つづく", english: "to continue", class: :godan, frequency: 557},
    %Verb{kanji: nil, kana: "やる", english: "to do", class: :godan, frequency: 563},
    %Verb{kanji: "出す", kana: "だす", english: "to take out", class: :godan, frequency: 565},
    %Verb{kanji: "語る", kana: "かたる", english: "to talk about", class: :godan, frequency: 598},
    %Verb{
      kanji: "使う",
      kana: "つかう",
      english: "to use (a tool, method, etc.)",
      class: :godan,
      frequency: 629
    },
    %Verb{kanji: "聞く", kana: "きく", english: "to hear", class: :godan, frequency: 703},
    %Verb{kanji: nil, kana: "しまう", english: "to finish", class: :godan, frequency: 713},
    %Verb{kanji: "始める", kana: "はじめる", english: "to start", class: :ichidan, frequency: 729},
    %Verb{
      kanji: "向ける",
      kana: "むける",
      english: "to turn (towards)",
      class: :ichidan,
      frequency: 774
    },
    %Verb{kanji: "始まる", kana: "はじまる", english: "to begin", class: :godan, frequency: 778},
    %Verb{kanji: "増える", kana: "ふえる", english: "to increase", class: :ichidan, frequency: 811},
    %Verb{
      kanji: "目指す",
      kana: "めざす",
      english: "to aim at (for, to do, to become)",
      class: :godan,
      frequency: 852
    },
    %Verb{kanji: "分かる", kana: "わかる", english: "to understand", class: :godan, frequency: 869},
    %Verb{kanji: "決まる", kana: "きまる", english: "to be decided", class: :godan, frequency: 884},
    %Verb{kanji: nil, kana: "まとめる", english: "to collect", class: :ichidan, frequency: 927},
    %Verb{kanji: "認める", kana: "みとめる", english: "to recognize", class: :ichidan, frequency: 946},
    %Verb{kanji: "続ける", kana: "つづける", english: "to continue", class: :ichidan, frequency: 957},
    %Verb{kanji: "含む", kana: "ふくむ", english: "to contain", class: :godan, frequency: 965},
    %Verb{kanji: "開く", kana: "ひらく", english: "to open", class: :godan, frequency: 1009},
    %Verb{kanji: "作る", kana: "つくる", english: "to make", class: :godan, frequency: 1023},
    %Verb{kanji: "起きる", kana: "おきる", english: "to get up", class: :ichidan, frequency: 1040},
    %Verb{kanji: "進める", kana: "すすめる", english: "to advance", class: :ichidan, frequency: 1047},
    %Verb{kanji: "得る", kana: "える", english: "to get", class: :ichidan, frequency: 1070},
    %Verb{kanji: "違う", kana: "ちがう", english: "to differ (from)", class: :godan, frequency: 1071},
    %Verb{kanji: "見せる", kana: "みせる", english: "to show", class: :ichidan, frequency: 1100},
    %Verb{kanji: "進む", kana: "すすむ", english: "to advance", class: :godan, frequency: 1105},
    %Verb{kanji: "経る", kana: "へる", english: "to pass", class: :ichidan, frequency: 1145},
    %Verb{kanji: nil, kana: "くれる", english: "to give", class: :ichidan, frequency: 1151},
    %Verb{kanji: "終わる", kana: "おわる", english: "to end", class: :godan, frequency: 1157},
    %Verb{
      kanji: "来る",
      kana: "くる",
      english: "to come (spatially or temporally)",
      class: :kuru,
      frequency: 1176
    },
    %Verb{
      kanji: "合わせる",
      kana: "あわせる",
      english: "to match (rhythm, speed, etc.)",
      class: :ichidan,
      frequency: 1188
    },
    %Verb{kanji: "知る", kana: "しる", english: "to know", class: :godan, frequency: 1197},
    %Verb{
      kanji: "含める",
      kana: "ふくめる",
      english: "to include (in a group or scope)",
      class: :ichidan,
      frequency: 1199
    },
    %Verb{kanji: "書く", kana: "かく", english: "to write", class: :godan, frequency: 1204},
    %Verb{kanji: "比べる", kana: "くらべる", english: "to compare", class: :ichidan, frequency: 1209},
    %Verb{kanji: "立つ", kana: "たつ", english: "to stand (up)", class: :godan, frequency: 1210},
    %Verb{kanji: "取る", kana: "とる", english: "to take", class: :godan, frequency: 1256},
    %Verb{kanji: "集める", kana: "あつめる", english: "to collect", class: :ichidan, frequency: 1263},
    %Verb{kanji: "答える", kana: "こたえる", english: "to answer", class: :ichidan, frequency: 1289},
    %Verb{kanji: "訴える", kana: "うったえる", english: "to raise", class: :ichidan, frequency: 1298},
    %Verb{kanji: "変わる", kana: "かわる", english: "to change", class: :godan, frequency: 1303},
    %Verb{kanji: "入れる", kana: "いれる", english: "to put in", class: :ichidan, frequency: 1307},
    %Verb{kanji: "図る", kana: "はかる", english: "to plan", class: :godan, frequency: 1316},
    %Verb{kanji: "呼ぶ", kana: "よぶ", english: "to call out (to)", class: :godan, frequency: 1357},
    %Verb{kanji: "残る", kana: "のこる", english: "to remain", class: :godan, frequency: 1367},
    %Verb{
      kanji: "迎える",
      kana: "むかえる",
      english: "to go out to meet",
      class: :ichidan,
      frequency: 1407
    },
    %Verb{kanji: "伝える", kana: "つたえる", english: "to convey", class: :ichidan, frequency: 1410},
    %Verb{kanji: "加える", kana: "くわえる", english: "to add", class: :ichidan, frequency: 1481},
    %Verb{kanji: "伴う", kana: "ともなう", english: "to accompany", class: :godan, frequency: 1501},
    %Verb{kanji: "生まれる", kana: "うまれる", english: "to be born", class: :ichidan, frequency: 1503},
    %Verb{kanji: "超える", kana: "こえる", english: "to cross over", class: :ichidan, frequency: 1532},
    %Verb{
      kanji: "与える",
      kana: "あたえる",
      english: "to give (esp. to someone of lower status)",
      class: :ichidan,
      frequency: 1605
    },
    %Verb{kanji: "感じる", kana: "かんじる", english: "to feel", class: :ichidan, frequency: 1608},
    %Verb{kanji: "行く", kana: "いく", english: "to go", class: :iku, frequency: 1639},
    %Verb{
      kanji: "相次ぐ",
      kana: "あいつぐ",
      english: "to follow in succession",
      class: :godan,
      frequency: 1641
    },
    %Verb{
      kanji: "住む",
      kana: "すむ",
      english: "to live (of humans)",
      class: :godan,
      frequency: 1724
    },
    %Verb{kanji: "占める", kana: "しめる", english: "to account for", class: :ichidan, frequency: 1733},
    %Verb{kanji: "応じる", kana: "おうじる", english: "to respond", class: :ichidan, frequency: 1749},
    %Verb{
      kanji: "乗る",
      kana: "のる",
      english: "to get on (train, plane, bus, ship, etc.)",
      class: :godan,
      frequency: 1753
    },
    %Verb{kanji: "調べる", kana: "しらべる", english: "to examine", class: :ichidan, frequency: 1764},
    %Verb{kanji: "生きる", kana: "いきる", english: "to live", class: :ichidan, frequency: 1780},
    %Verb{kanji: "上がる", kana: "あがる", english: "to rise", class: :godan, frequency: 1783},
    %Verb{kanji: "描く", kana: "えがく", english: "to draw", class: :godan, frequency: 1796},
    %Verb{kanji: "守る", kana: "まもる", english: "to protect", class: :godan, frequency: 1798},
    %Verb{kanji: "広がる", kana: "ひろがる", english: "to spread (out)", class: :godan, frequency: 1824},
    %Verb{kanji: "見える", kana: "みえる", english: "to be seen", class: :ichidan, frequency: 1840},
    %Verb{kanji: "選ぶ", kana: "えらぶ", english: "to choose", class: :godan, frequency: 1859},
    %Verb{kanji: "務める", kana: "つとめる", english: "to work (for)", class: :ichidan, frequency: 1871},
    %Verb{kanji: "除く", kana: "のぞく", english: "to remove", class: :godan, frequency: 1881},
    %Verb{
      kanji: "戻る",
      kana: "もどる",
      english: "to turn back (e.g. half-way)",
      class: :godan,
      frequency: 1890
    },
    %Verb{kanji: "置く", kana: "おく", english: "to put", class: :godan, frequency: 1910},
    %Verb{kanji: "残す", kana: "のこす", english: "to leave (behind)", class: :godan, frequency: 1914},
    %Verb{kanji: "高まる", kana: "たかまる", english: "to rise", class: :godan, frequency: 1932},
    %Verb{kanji: "集まる", kana: "あつまる", english: "to gather", class: :godan, frequency: 1941},
    %Verb{
      kanji: "取り組む",
      kana: "とりくむ",
      english: "to grapple with",
      class: :godan,
      frequency: 1943
    },
    %Verb{
      kanji: "狙う",
      kana: "ねらう",
      english: "to aim at (with a weapon, etc.)",
      class: :godan,
      frequency: 1949
    },
    %Verb{kanji: "果たす", kana: "はたす", english: "to accomplish", class: :godan, frequency: 1950},
    %Verb{kanji: "向かう", kana: "むかう", english: "to face", class: :godan, frequency: 1957},
    %Verb{kanji: "訪れる", kana: "おとずれる", english: "to visit", class: :ichidan, frequency: 1959},
    %Verb{kanji: "打ち出す", kana: "うちだす", english: "to emboss", class: :godan, frequency: 1971},
    %Verb{
      kanji: "減る",
      kana: "へる",
      english: "to decrease (in size or number)",
      class: :godan,
      frequency: 2003
    },
    %Verb{kanji: "買う", kana: "かう", english: "to buy", class: :godan, frequency: 2024},
    %Verb{kanji: "上げる", kana: "あげる", english: "to raise", class: :ichidan, frequency: 2036},
    %Verb{
      kanji: "離れる",
      kana: "はなれる",
      english: "to be separated",
      class: :ichidan,
      frequency: 2048
    },
    %Verb{kanji: "強まる", kana: "つよまる", english: "to get strong", class: :godan, frequency: 2056},
    %Verb{kanji: "死ぬ", kana: "しぬ", english: "to die", class: :godan, frequency: 2062},
    %Verb{kanji: "失う", kana: "うしなう", english: "to lose", class: :godan, frequency: 2084},
    %Verb{kanji: nil, kana: "かかわる", english: "to stick (to)", class: :godan, frequency: 2086},
    %Verb{
      kanji: "目立つ",
      kana: "めだつ",
      english: "to be conspicuous",
      class: :godan,
      frequency: 2100
    },
    %Verb{kanji: "読む", kana: "よむ", english: "to read", class: :godan, frequency: 2103},
    %Verb{kanji: "送る", kana: "おくる", english: "to send", class: :godan, frequency: 2108},
    %Verb{
      kanji: "基づく",
      kana: "もとづく",
      english: "to be based (on)",
      class: :godan,
      frequency: 2120
    },
    %Verb{kanji: "働く", kana: "はたらく", english: "to work", class: :godan, frequency: 2122},
    %Verb{
      kanji: "上回る",
      kana: "うわまわる",
      english: "to exceed (esp. figures: profits, unemployment rate, etc.)",
      class: :godan,
      frequency: 2125
    },
    %Verb{kanji: "似る", kana: "にる", english: "to resemble", class: :ichidan, frequency: 2134},
    %Verb{kanji: "見つかる", kana: "みつかる", english: "to be found", class: :godan, frequency: 2140},
    %Verb{kanji: "待つ", kana: "まつ", english: "to wait", class: :godan, frequency: 2156},
    %Verb{kanji: "終える", kana: "おえる", english: "to finish", class: :ichidan, frequency: 2204},
    %Verb{kanji: "変える", kana: "かえる", english: "to change", class: :ichidan, frequency: 2224},
    %Verb{kanji: "固める", kana: "かためる", english: "to harden", class: :ichidan, frequency: 2252},
    %Verb{kanji: "迫る", kana: "せまる", english: "to approach", class: :godan, frequency: 2279},
    %Verb{kanji: "帰る", kana: "かえる", english: "to return", class: :godan, frequency: 2389},
    %Verb{
      kanji: "出来る",
      kana: "できる",
      english: "to be able to do",
      class: :ichidan,
      frequency: 2423
    },
    %Verb{kanji: "勝る", kana: "まさる", english: "to excel", class: :godan, frequency: 2460},
    %Verb{kanji: "報じる", kana: "ほうじる", english: "to report", class: :ichidan, frequency: 2470},
    %Verb{kanji: "並ぶ", kana: "ならぶ", english: "to line up", class: :godan, frequency: 2476},
    %Verb{kanji: "切る", kana: "きる", english: "to cut", class: :godan, frequency: 2478},
    %Verb{kanji: "起こす", kana: "おこす", english: "to raise", class: :godan, frequency: 2506},
    %Verb{kanji: "遅れる", kana: "おくれる", english: "to be late", class: :ichidan, frequency: 2516},
    %Verb{kanji: "打つ", kana: "うつ", english: "to hit", class: :godan, frequency: 2536},
    %Verb{kanji: "走る", kana: "はしる", english: "to run", class: :godan, frequency: 2571},
    %Verb{kanji: "落ちる", kana: "おちる", english: "to fall", class: :ichidan, frequency: 2584},
    %Verb{kanji: "流れる", kana: "ながれる", english: "to stream", class: :ichidan, frequency: 2594},
    %Verb{kanji: "消える", kana: "きえる", english: "to disappear", class: :ichidan, frequency: 2597},
    %Verb{
      kanji: "抱える",
      kana: "かかえる",
      english: "to hold in one's arms",
      class: :ichidan,
      frequency: 2598
    },
    %Verb{kanji: "異なる", kana: "ことなる", english: "to differ", class: :godan, frequency: 2606},
    %Verb{kanji: "受け取る", kana: "うけとる", english: "to receive", class: :godan, frequency: 2609},
    %Verb{
      kanji: "呼びかける",
      kana: "よびかける",
      english: "to call out to",
      class: :ichidan,
      frequency: 2613
    },
    %Verb{kanji: "教える", kana: "おしえる", english: "to teach", class: :ichidan, frequency: 2617},
    %Verb{kanji: "強める", kana: "つよめる", english: "to strengthen", class: :ichidan, frequency: 2621},
    %Verb{kanji: "会う", kana: "あう", english: "to meet", class: :godan, frequency: 2623},
    %Verb{kanji: "回る", kana: "まわる", english: "to turn", class: :godan, frequency: 2667},
    %Verb{kanji: "歩く", kana: "あるく", english: "to walk", class: :godan, frequency: 2729},
    %Verb{kanji: "繰り返す", kana: "くりかえす", english: "to repeat", class: :godan, frequency: 2743},
    %Verb{kanji: "亡くなる", kana: "なくなる", english: "to die", class: :godan, frequency: 2780},
    %Verb{kanji: "盛り込む", kana: "もりこむ", english: "to incorporate", class: :godan, frequency: 2783},
    %Verb{kanji: "加わる", kana: "くわわる", english: "to be added to", class: :godan, frequency: 2785},
    %Verb{kanji: "重ねる", kana: "かさねる", english: "to pile up", class: :ichidan, frequency: 2835},
    %Verb{kanji: "受け入れる", kana: "うけいれる", english: "to accept", class: :ichidan, frequency: 2864},
    %Verb{kanji: "上る", kana: "のぼる", english: "to ascend", class: :godan, frequency: 2872},
    %Verb{
      kanji: "掲げる",
      kana: "かかげる",
      english: "to put up (a notice, sign, etc.)",
      class: :ichidan,
      frequency: 2916
    },
    %Verb{
      kanji: "抑える",
      kana: "おさえる",
      english: "to keep within limits (e.g. spending)",
      class: :ichidan,
      frequency: 2934
    },
    %Verb{
      kanji: "生かす",
      kana: "いかす",
      english: "to make (the best) use of",
      class: :godan,
      frequency: 2942
    },
    %Verb{kanji: "食べる", kana: "たべる", english: "to eat", class: :ichidan, frequency: 2947},
    %Verb{kanji: "防ぐ", kana: "ふせぐ", english: "to defend against", class: :godan, frequency: 2947},
    %Verb{kanji: "及ぶ", kana: "およぶ", english: "to reach", class: :godan, frequency: 2963},
    %Verb{kanji: "定める", kana: "さだめる", english: "to decide", class: :ichidan, frequency: 2969},
    %Verb{kanji: "招く", kana: "まねく", english: "to invite", class: :godan, frequency: 2998},
    %Verb{
      kanji: "避ける",
      kana: "よける",
      english: "to avoid (physical contact with)",
      class: :ichidan,
      frequency: 3005
    },
    %Verb{kanji: "許す", kana: "ゆるす", english: "to permit", class: :godan, frequency: 3018},
    %Verb{kanji: "込む", kana: "こむ", english: "to be crowded", class: :godan, frequency: 3022},
    %Verb{kanji: "結ぶ", kana: "むすぶ", english: "to tie", class: :godan, frequency: 3026},
    %Verb{
      kanji: "奪う",
      kana: "うばう",
      english: "to take (by force)",
      class: :godan,
      frequency: 3032
    },
    %Verb{
      kanji: "探る",
      kana: "さぐる",
      english: "to feel around for",
      class: :godan,
      frequency: 3037
    },
    %Verb{kanji: "踏み切る", kana: "ふみきる", english: "to take off", class: :godan, frequency: 3039},
    %Verb{
      kanji: nil,
      kana: "させる",
      english: "to make (someone) do",
      class: :ichidan,
      frequency: 3055
    },
    %Verb{kanji: "話し合う", kana: "はなしあう", english: "to discuss", class: :godan, frequency: 3058},
    %Verb{kanji: "広げる", kana: "ひろげる", english: "to spread", class: :ichidan, frequency: 3068},
    %Verb{kanji: "代わる", kana: "かわる", english: "to succeed", class: :godan, frequency: 3082},
    %Verb{kanji: "願う", kana: "ねがう", english: "to desire", class: :godan, frequency: 3088},
    %Verb{
      kanji: "備える",
      kana: "そなえる",
      english: "to furnish with",
      class: :ichidan,
      frequency: 3092
    },
    %Verb{kanji: "望む", kana: "のぞむ", english: "to desire", class: :godan, frequency: 3093},
    %Verb{kanji: "寄せる", kana: "よせる", english: "to come near", class: :ichidan, frequency: 3097},
    %Verb{kanji: "支える", kana: "ささえる", english: "to support", class: :ichidan, frequency: 3098},
    %Verb{kanji: "忘れる", kana: "わすれる", english: "to forget", class: :ichidan, frequency: 3101},
    %Verb{kanji: "驚く", kana: "おどろく", english: "to be surprised", class: :godan, frequency: 3103},
    %Verb{
      kanji: "浴びる",
      kana: "あびる",
      english: "to dash over oneself (e.g. water)",
      class: :ichidan,
      frequency: 3123
    },
    %Verb{kanji: "動く", kana: "うごく", english: "to move", class: :godan, frequency: 3133},
    %Verb{
      kanji: "敗れる",
      kana: "やぶれる",
      english: "to be defeated",
      class: :ichidan,
      frequency: 3137
    },
    %Verb{
      kanji: "贈る",
      kana: "おくる",
      english: "to give (as a gift)",
      class: :godan,
      frequency: 3142
    },
    %Verb{kanji: "沿う", kana: "そう", english: "to run along", class: :godan, frequency: 3154},
    %Verb{
      kanji: "分ける",
      kana: "わける",
      english: "to divide (into)",
      class: :ichidan,
      frequency: 3177
    },
    %Verb{kanji: "追い込む", kana: "おいこむ", english: "to herd", class: :godan, frequency: 3185},
    %Verb{
      kanji: "控える",
      kana: "ひかえる",
      english: "to be temperate in",
      class: :ichidan,
      frequency: 3194
    },
    %Verb{kanji: "困る", kana: "こまる", english: "to be troubled", class: :godan, frequency: 3195},
    %Verb{kanji: "限る", kana: "かぎる", english: "to restrict", class: :godan, frequency: 3204},
    %Verb{
      kanji: "演じる",
      kana: "えんじる",
      english: "to act (a part)",
      class: :ichidan,
      frequency: 3211
    },
    %Verb{kanji: "当たる", kana: "あたる", english: "to be hit", class: :godan, frequency: 3212},
    %Verb{
      kanji: "陥る",
      kana: "おちいる",
      english: "to fall into (e.g. a hole)",
      class: :godan,
      frequency: 3213
    },
    %Verb{kanji: "付ける", kana: "つける", english: "to attach", class: :ichidan, frequency: 3221},
    %Verb{
      kanji: "通う",
      kana: "かよう",
      english: "to go to and from (a place)",
      class: :godan,
      frequency: 3238
    },
    %Verb{kanji: "設ける", kana: "もうける", english: "to prepare", class: :ichidan, frequency: 3243},
    %Verb{kanji: "臨む", kana: "のぞむ", english: "to look out on", class: :godan, frequency: 3252},
    %Verb{kanji: "現れる", kana: "あらわれる", english: "to appear", class: :ichidan, frequency: 3259},
    %Verb{kanji: "訪ねる", kana: "たずねる", english: "to visit", class: :ichidan, frequency: 3269},
    %Verb{kanji: "起こる", kana: "おこる", english: "to occur", class: :godan, frequency: 3280},
    %Verb{
      kanji: "倒れる",
      kana: "たおれる",
      english: "to fall (over, down)",
      class: :ichidan,
      frequency: 3288
    },
    %Verb{
      kanji: "寝る",
      kana: "ねる",
      english: "to sleep (lying down)",
      class: :ichidan,
      frequency: 3289
    },
    %Verb{kanji: "追う", kana: "おう", english: "to chase", class: :godan, frequency: 3290},
    %Verb{kanji: "乗り出す", kana: "のりだす", english: "to set out", class: :godan, frequency: 3298},
    %Verb{kanji: "負ける", kana: "まける", english: "to lose", class: :ichidan, frequency: 3299},
    %Verb{kanji: "覚える", kana: "おぼえる", english: "to memorize", class: :ichidan, frequency: 3329},
    %Verb{kanji: "投げる", kana: "なげる", english: "to throw", class: :ichidan, frequency: 3331},
    %Verb{
      kanji: "見直す",
      kana: "みなおす",
      english: "to look at again",
      class: :godan,
      frequency: 3332
    },
    %Verb{
      kanji: "超す",
      kana: "こす",
      english: "to cross over (e.g. mountain)",
      class: :godan,
      frequency: 3339
    },
    %Verb{kanji: "張る", kana: "はる", english: "to stick", class: :godan, frequency: 3342},
    %Verb{kanji: "伸びる", kana: "のびる", english: "to stretch", class: :ichidan, frequency: 3349},
    %Verb{
      kanji: "組む",
      kana: "くむ",
      english: "to cross (legs or arms)",
      class: :godan,
      frequency: 3350
    },
    %Verb{kanji: "生じる", kana: "しょうじる", english: "to produce", class: :ichidan, frequency: 3354},
    %Verb{kanji: "売る", kana: "うる", english: "to sell", class: :godan, frequency: 3367},
    %Verb{kanji: "学ぶ", kana: "まなぶ", english: "to learn", class: :godan, frequency: 3368},
    %Verb{kanji: "握る", kana: "にぎる", english: "to clasp", class: :godan, frequency: 3375},
    %Verb{kanji: "破る", kana: "やぶる", english: "to tear", class: :godan, frequency: 3376},
    %Verb{kanji: "分かれる", kana: "わかれる", english: "to branch", class: :ichidan, frequency: 3377},
    %Verb{kanji: nil, kana: "ある", english: "to be", class: :aru, frequency: 3379},
    %Verb{
      kanji: "連れる",
      kana: "つれる",
      english: "to take (someone) with one",
      class: :ichidan,
      frequency: 3382
    },
    %Verb{
      kanji: "育つ",
      kana: "そだつ",
      english: "to be raised (e.g. child)",
      class: :godan,
      frequency: 3385
    },
    %Verb{kanji: "流す", kana: "ながす", english: "to drain", class: :godan, frequency: 3391},
    %Verb{kanji: "楽しむ", kana: "たのしむ", english: "to enjoy", class: :godan, frequency: 3410},
    %Verb{kanji: "見つける", kana: "みつける", english: "to find", class: :ichidan, frequency: 3411},
    %Verb{
      kanji: "踏まえる",
      kana: "ふまえる",
      english: "to be based on",
      class: :ichidan,
      frequency: 3412
    },
    %Verb{kanji: "高める", kana: "たかめる", english: "to raise", class: :ichidan, frequency: 3418},
    %Verb{kanji: "下がる", kana: "さがる", english: "to come down", class: :godan, frequency: 3428},
    %Verb{
      kanji: "過ぎる",
      kana: "すぎる",
      english: "to pass through",
      class: :ichidan,
      frequency: 3430
    },
    %Verb{kanji: "飛ぶ", kana: "とぶ", english: "to fly", class: :godan, frequency: 3432},
    %Verb{kanji: "落ち込む", kana: "おちこむ", english: "to feel down", class: :godan, frequency: 3442},
    %Verb{
      kanji: "負う",
      kana: "おう",
      english: "to carry on one's back",
      class: :godan,
      frequency: 3445
    },
    %Verb{kanji: "増やす", kana: "ふやす", english: "to increase", class: :godan, frequency: 3446},
    %Verb{kanji: "付く", kana: "つく", english: "to be attached", class: :godan, frequency: 3448},
    %Verb{kanji: "借りる", kana: "かりる", english: "to borrow", class: :ichidan, frequency: 3452},
    %Verb{kanji: "頑張る", kana: "がんばる", english: "to persevere", class: :godan, frequency: 3453},
    %Verb{kanji: "触れる", kana: "ふれる", english: "to touch", class: :ichidan, frequency: 3465},
    %Verb{kanji: "落とす", kana: "おとす", english: "to drop", class: :godan, frequency: 3481},
    %Verb{
      kanji: nil,
      kana: "もたらす",
      english: "to bring (news, knowledge, etc.)",
      class: :godan,
      frequency: 3489
    },
    %Verb{kanji: "増す", kana: "ます", english: "to increase", class: :godan, frequency: 3498},
    %Verb{
      kanji: "呼び掛ける",
      kana: "よびかける",
      english: "to call out to",
      class: :ichidan,
      frequency: 3506
    },
    %Verb{kanji: "喜ぶ", kana: "よろこぶ", english: "to be delighted", class: :godan, frequency: 3522},
    %Verb{kanji: "命じる", kana: "めいじる", english: "to order", class: :ichidan, frequency: 3525},
    %Verb{kanji: "合う", kana: "あう", english: "to come together", class: :godan, frequency: 3526},
    %Verb{kanji: "次ぐ", kana: "つぐ", english: "to follow", class: :godan, frequency: 3527},
    %Verb{
      kanji: "抱く",
      kana: "だく",
      english: "to hold in one's arms (e.g. a baby)",
      class: :godan,
      frequency: 3534
    },
    %Verb{kanji: "届く", kana: "とどく", english: "to reach", class: :godan, frequency: 3540},
    %Verb{
      kanji: "思い切る",
      kana: "おもいきる",
      english: "to give up (all thoughts of)",
      class: :godan,
      frequency: 3546
    },
    %Verb{kanji: "生む", kana: "うむ", english: "to give birth", class: :godan, frequency: 3547},
    %Verb{kanji: "信じる", kana: "しんじる", english: "to believe", class: :ichidan, frequency: 3569},
    %Verb{kanji: "飲む", kana: "のむ", english: "to drink", class: :godan, frequency: 3576},
    %Verb{kanji: "受け止める", kana: "うけとめる", english: "to catch", class: :ichidan, frequency: 3587},
    %Verb{
      kanji: "至る",
      kana: "いたる",
      english: "to arrive at (e.g. a decision)",
      class: :godan,
      frequency: 3590
    },
    %Verb{
      kanji: "優れる",
      kana: "すぐれる",
      english: "to be better (than)",
      class: :ichidan,
      frequency: 3591
    },
    %Verb{kanji: "急ぐ", kana: "いそぐ", english: "to hurry", class: :godan, frequency: 3597},
    %Verb{kanji: "殺す", kana: "ころす", english: "to kill", class: :godan, frequency: 3600},
    %Verb{kanji: "放る", kana: "ほうる", english: "to throw", class: :godan, frequency: 3601},
    %Verb{kanji: "勝つ", kana: "かつ", english: "to win", class: :godan, frequency: 3604},
    %Verb{kanji: "立てる", kana: "たてる", english: "to stand up", class: :ichidan, frequency: 3616},
    %Verb{
      kanji: "渡す",
      kana: "わたす",
      english: "to ferry across (e.g. a river)",
      class: :godan,
      frequency: 3630
    },
    %Verb{kanji: "減らす", kana: "へらす", english: "to abate", class: :godan, frequency: 3632},
    %Verb{kanji: "渡る", kana: "わたる", english: "to cross over", class: :godan, frequency: 3651},
    %Verb{
      kanji: "乗せる",
      kana: "のせる",
      english: "to place on (something)",
      class: :ichidan,
      frequency: 3675
    },
    %Verb{
      kanji: "開ける",
      kana: "あける",
      english: "to open (a door, etc.)",
      class: :ichidan,
      frequency: 3682
    },
    %Verb{
      kanji: "足りる",
      kana: "たりる",
      english: "to be sufficient",
      class: :ichidan,
      frequency: 3684
    },
    %Verb{kanji: "固まる", kana: "かたまる", english: "to harden", class: :godan, frequency: 3688},
    %Verb{kanji: "引く", kana: "ひく", english: "to pull", class: :godan, frequency: 3689},
    %Verb{
      kanji: "着る",
      kana: "きる",
      english: "to wear (from the shoulders down)",
      class: :ichidan,
      frequency: 3692
    },
    %Verb{kanji: "争う", kana: "あらそう", english: "to compete", class: :godan, frequency: 3697},
    %Verb{kanji: "聴く", kana: "きく", english: "to hear", class: :godan, frequency: 3702},
    %Verb{kanji: "引き上げる", kana: "ひきあげる", english: "to pull up", class: :ichidan, frequency: 3704},
    %Verb{
      kanji: "伝わる",
      kana: "つたわる",
      english: "to spread (of a rumour, news, etc.)",
      class: :godan,
      frequency: 3706
    },
    %Verb{kanji: "運ぶ", kana: "はこぶ", english: "to carry", class: :godan, frequency: 3708},
    %Verb{
      kanji: "通じる",
      kana: "つうじる",
      english: "to be open (to traffic)",
      class: :ichidan,
      frequency: 3715
    },
    %Verb{kanji: "落ち着く", kana: "おちつく", english: "to calm down", class: :godan, frequency: 3716},
    %Verb{kanji: "絡む", kana: "からむ", english: "to twine", class: :godan, frequency: 3718},
    %Verb{
      kanji: "扱う",
      kana: "あつかう",
      english: "to deal with (a person)",
      class: :godan,
      frequency: 3722
    },
    %Verb{
      kanji: "払う",
      kana: "はらう",
      english: "to pay (e.g. money, bill)",
      class: :godan,
      frequency: 3731
    },
    %Verb{kanji: "売れる", kana: "うれる", english: "to sell (well)", class: :ichidan, frequency: 3734},
    %Verb{kanji: "包む", kana: "つつむ", english: "to wrap up", class: :godan, frequency: 3740},
    %Verb{kanji: "転じる", kana: "てんじる", english: "to turn", class: :ichidan, frequency: 3746},
    %Verb{
      kanji: "申し入れる",
      kana: "もうしいれる",
      english: "to propose",
      class: :ichidan,
      frequency: 3758
    },
    %Verb{kanji: "捨てる", kana: "すてる", english: "to throw away", class: :ichidan, frequency: 3766},
    %Verb{kanji: "歌う", kana: "うたう", english: "to sing", class: :godan, frequency: 3771},
    %Verb{kanji: "下げる", kana: "さげる", english: "to hang", class: :ichidan, frequency: 3791},
    %Verb{kanji: "誇る", kana: "ほこる", english: "to boast of", class: :godan, frequency: 3792},
    %Verb{kanji: "笑う", kana: "わらう", english: "to laugh", class: :godan, frequency: 3797},
    %Verb{kanji: "育てる", kana: "そだてる", english: "to raise", class: :ichidan, frequency: 3799},
    %Verb{kanji: "促す", kana: "うながす", english: "to urge", class: :godan, frequency: 3799},
    %Verb{kanji: "役立つ", kana: "やくだつ", english: "to be useful", class: :godan, frequency: 3810},
    %Verb{
      kanji: "伸ばす",
      kana: "のばす",
      english: "to grow long (e.g. hair, nails)",
      class: :godan,
      frequency: 3814
    },
    %Verb{kanji: "支払う", kana: "しはらう", english: "to pay", class: :godan, frequency: 3821},
    %Verb{kanji: "越える", kana: "こえる", english: "to cross over", class: :ichidan, frequency: 3825},
    %Verb{kanji: "表れる", kana: "あらわれる", english: "to appear", class: :ichidan, frequency: 3829},
    %Verb{kanji: "応える", kana: "こたえる", english: "to respond", class: :ichidan, frequency: 3831},
    %Verb{
      kanji: "振り返る",
      kana: "ふりかえる",
      english: "to turn one's head",
      class: :godan,
      frequency: 3831
    },
    %Verb{kanji: "欠く", kana: "かく", english: "to chip", class: :godan, frequency: 3852},
    %Verb{kanji: "悩む", kana: "なやむ", english: "to be worried", class: :godan, frequency: 3861},
    %Verb{kanji: "飾る", kana: "かざる", english: "to decorate", class: :godan, frequency: 3866},
    %Verb{
      kanji: "担う",
      kana: "になう",
      english: "to carry on one's shoulder",
      class: :godan,
      frequency: 3896
    },
    %Verb{kanji: "取り上げる", kana: "とりあげる", english: "to pick up", class: :ichidan, frequency: 3903},
    %Verb{kanji: "逃げる", kana: "にげる", english: "to run away", class: :ichidan, frequency: 3904},
    %Verb{
      kanji: "暮らす",
      kana: "くらす",
      english: "to live (on, by, etc.)",
      class: :godan,
      frequency: 3910
    },
    %Verb{kanji: "崩れる", kana: "くずれる", english: "to collapse", class: :ichidan, frequency: 3930},
    %Verb{kanji: "過ごす", kana: "すごす", english: "to spend (time)", class: :godan, frequency: 3932},
    %Verb{
      kanji: "込める",
      kana: "こめる",
      english: "to load (a gun, etc.)",
      class: :ichidan,
      frequency: 3939
    },
    %Verb{kanji: "響く", kana: "ひびく", english: "to resound", class: :godan, frequency: 3945},
    %Verb{kanji: "巻き込む", kana: "まきこむ", english: "to roll up", class: :godan, frequency: 3952},
    %Verb{kanji: "消す", kana: "けす", english: "to erase", class: :godan, frequency: 3957},
    %Verb{kanji: "生る", kana: "なる", english: "to bear fruit", class: :godan, frequency: 3959},
    %Verb{kanji: "聞こえる", kana: "きこえる", english: "to be heard", class: :ichidan, frequency: 3968},
    %Verb{kanji: "戦う", kana: "たたかう", english: "to make war (on)", class: :godan, frequency: 3971},
    %Verb{kanji: "崩す", kana: "くずす", english: "to destroy", class: :godan, frequency: 3990},
    %Verb{kanji: "去る", kana: "さる", english: "to leave", class: :godan, frequency: 4006},
    %Verb{kanji: "座る", kana: "すわる", english: "to sit (down)", class: :godan, frequency: 4011},
    %Verb{kanji: "止まる", kana: "とまる", english: "to stop (moving)", class: :godan, frequency: 4012},
    %Verb{kanji: "止める", kana: "とめる", english: "to stop", class: :ichidan, frequency: 4014},
    %Verb{kanji: "飛び出す", kana: "とびだす", english: "to jump out", class: :godan, frequency: 4016},
    %Verb{kanji: "深める", kana: "ふかめる", english: "to deepen", class: :ichidan, frequency: 4018},
    %Verb{kanji: "切れる", kana: "きれる", english: "to break", class: :ichidan, frequency: 4019},
    %Verb{kanji: "強いる", kana: "しいる", english: "to force", class: :ichidan, frequency: 4025},
    %Verb{
      kanji: "返す",
      kana: "かえす",
      english: "to return (something)",
      class: :godan,
      frequency: 4035
    },
    %Verb{kanji: "積む", kana: "つむ", english: "to pile up", class: :godan, frequency: 4037},
    %Verb{kanji: "充てる", kana: "あてる", english: "to assign", class: :ichidan, frequency: 4038},
    %Verb{kanji: "持ち込む", kana: "もちこむ", english: "to bring in", class: :godan, frequency: 4051},
    %Verb{
      kanji: "絞る",
      kana: "しぼる",
      english: "to wring (towel, rag)",
      class: :godan,
      frequency: 4055
    },
    %Verb{kanji: "満ちる", kana: "みちる", english: "to fill", class: :ichidan, frequency: 4059},
    %Verb{kanji: "割る", kana: "わる", english: "to divide", class: :godan, frequency: 4060},
    %Verb{kanji: "抜く", kana: "ぬく", english: "to pull out", class: :godan, frequency: 4075},
    %Verb{kanji: "断る", kana: "ことわる", english: "to refuse", class: :godan, frequency: 4082},
    %Verb{kanji: "襲う", kana: "おそう", english: "to attack", class: :godan, frequency: 4083},
    %Verb{kanji: "輝く", kana: "かがやく", english: "to shine", class: :godan, frequency: 4086},
    %Verb{kanji: "取り入れる", kana: "とりいれる", english: "to take in", class: :ichidan, frequency: 4092},
    %Verb{kanji: "着く", kana: "つく", english: "to arrive at", class: :godan, frequency: 4095},
    %Verb{kanji: "苦しむ", kana: "くるしむ", english: "to suffer", class: :godan, frequency: 4102},
    %Verb{kanji: "囲む", kana: "かこむ", english: "to surround", class: :godan, frequency: 4103},
    %Verb{kanji: "探す", kana: "さがす", english: "to search for", class: :godan, frequency: 4104},
    %Verb{kanji: "築く", kana: "きずく", english: "to build", class: :godan, frequency: 4105},
    %Verb{kanji: "言い渡す", kana: "いいわたす", english: "to announce", class: :godan, frequency: 4108},
    %Verb{
      kanji: "及ぼす",
      kana: "およぼす",
      english: "to exert (influence)",
      class: :godan,
      frequency: 4113
    },
    %Verb{
      kanji: "努める",
      kana: "つとめる",
      english: "to endeavor (to do)",
      class: :ichidan,
      frequency: 4114
    },
    %Verb{kanji: "見守る", kana: "みまもる", english: "to watch over", class: :godan, frequency: 4142},
    %Verb{kanji: "頼む", kana: "たのむ", english: "to request", class: :godan, frequency: 4146},
    %Verb{kanji: "辞める", kana: "やめる", english: "to resign", class: :ichidan, frequency: 4159},
    %Verb{
      kanji: "誤る",
      kana: "あやまる",
      english: "to make a mistake (in)",
      class: :godan,
      frequency: 4163
    },
    %Verb{kanji: "間違う", kana: "まちがう", english: "to be mistaken", class: :godan, frequency: 4165},
    %Verb{kanji: "近づく", kana: "ちかづく", english: "to approach", class: :godan, frequency: 4166},
    %Verb{
      kanji: "移る",
      kana: "うつる",
      english: "to move (to another place or state)",
      class: :godan,
      frequency: 4192
    },
    %Verb{kanji: nil, kana: "ちゃう", english: "to do completely", class: :godan, frequency: 4196},
    %Verb{kanji: "抜ける", kana: "ぬける", english: "to come out", class: :ichidan, frequency: 4199},
    %Verb{kanji: "見込む", kana: "みこむ", english: "to anticipate", class: :godan, frequency: 4219},
    %Verb{kanji: "疲れる", kana: "つかれる", english: "to get tired", class: :ichidan, frequency: 4226},
    %Verb{
      kanji: "撮る",
      kana: "とる",
      english: "to take (a photograph)",
      class: :godan,
      frequency: 4233
    },
    %Verb{
      kanji: "出かける",
      kana: "でかける",
      english: "to go out (e.g. on an excursion or outing)",
      class: :ichidan,
      frequency: 4243
    },
    %Verb{kanji: "率いる", kana: "ひきいる", english: "to lead", class: :ichidan, frequency: 4245},
    %Verb{kanji: "向く", kana: "むく", english: "to turn toward", class: :godan, frequency: 4264},
    %Verb{kanji: "浮かぶ", kana: "うかぶ", english: "to float", class: :godan, frequency: 4266},
    %Verb{
      kanji: "恵まれる",
      kana: "めぐまれる",
      english: "to be blessed with",
      class: :ichidan,
      frequency: 4273
    },
    %Verb{kanji: "押す", kana: "おす", english: "to push", class: :godan, frequency: 4280},
    %Verb{kanji: "収める", kana: "おさめる", english: "to put (into)", class: :ichidan, frequency: 4290},
    %Verb{
      kanji: "挑む",
      kana: "いどむ",
      english: "to challenge to (a fight, game, etc.)",
      class: :godan,
      frequency: 4291
    },
    %Verb{kanji: "痛める", kana: "いためる", english: "to hurt", class: :ichidan, frequency: 4298},
    %Verb{
      kanji: "引き下げる",
      kana: "ひきさげる",
      english: "to lower (a price, tax, standard, etc.)",
      class: :ichidan,
      frequency: 4304
    },
    %Verb{kanji: "揺れる", kana: "ゆれる", english: "to shake", class: :ichidan, frequency: 4305},
    %Verb{
      kanji: "取れる",
      kana: "とれる",
      english: "to come off (of a button, handle, lid, etc.)",
      class: :ichidan,
      frequency: 4309
    },
    %Verb{kanji: "恐れる", kana: "おそれる", english: "to fear", class: :ichidan, frequency: 4316},
    %Verb{kanji: "勤める", kana: "つとめる", english: "to work (for)", class: :ichidan, frequency: 4322},
    %Verb{kanji: "載る", kana: "のる", english: "to be placed on", class: :godan, frequency: 4325},
    %Verb{kanji: "直す", kana: "なおす", english: "to repair", class: :godan, frequency: 4327},
    %Verb{kanji: "泣く", kana: "なく", english: "to cry", class: :godan, frequency: 4330},
    %Verb{kanji: "重なる", kana: "かさなる", english: "to be piled up", class: :godan, frequency: 4331},
    %Verb{
      kanji: "組み合わせる",
      kana: "くみあわせる",
      english: "to put together",
      class: :ichidan,
      frequency: 4332
    },
    %Verb{kanji: "欠ける", kana: "かける", english: "to chip", class: :ichidan, frequency: 4337},
    %Verb{kanji: "飛び込む", kana: "とびこむ", english: "to jump in", class: :godan, frequency: 4339},
    %Verb{kanji: "保つ", kana: "たもつ", english: "to keep", class: :godan, frequency: 4342},
    %Verb{
      kanji: "移す",
      kana: "うつす",
      english: "to transfer (to a different place, group, etc.)",
      class: :godan,
      frequency: 4351
    },
    %Verb{kanji: "隠す", kana: "かくす", english: "to hide", class: :godan, frequency: 4352},
    %Verb{
      kanji: "下す",
      kana: "くだす",
      english: "to make a decision",
      class: :godan,
      frequency: 4361
    },
    %Verb{kanji: "踏む", kana: "ふむ", english: "to step on", class: :godan, frequency: 4366},
    %Verb{kanji: "整う", kana: "ととのう", english: "to be ready", class: :godan, frequency: 4369},
    %Verb{kanji: "動かす", kana: "うごかす", english: "to move", class: :godan, frequency: 4372},
    %Verb{kanji: "詰める", kana: "つめる", english: "to stuff into", class: :ichidan, frequency: 4377},
    %Verb{kanji: "焼く", kana: "やく", english: "to burn", class: :godan, frequency: 4378},
    %Verb{
      kanji: nil,
      kana: "こだわる",
      english: "to be obsessive (about)",
      class: :godan,
      frequency: 4380
    },
    %Verb{
      kanji: "見舞う",
      kana: "みまう",
      english: "to visit and comfort or console",
      class: :godan,
      frequency: 4403
    },
    %Verb{kanji: "表す", kana: "あらわす", english: "to represent", class: :godan, frequency: 4412},
    %Verb{kanji: "試みる", kana: "こころみる", english: "to try", class: :ichidan, frequency: 4415},
    %Verb{
      kanji: "知れる",
      kana: "しれる",
      english: "to become known",
      class: :ichidan,
      frequency: 4416
    },
    %Verb{
      kanji: "浮かび上がる",
      kana: "うかびあがる",
      english: "to rise to the surface",
      class: :godan,
      frequency: 4417
    },
    %Verb{
      kanji: "見送る",
      kana: "みおくる",
      english: "to see (someone) off",
      class: :godan,
      frequency: 4421
    },
    %Verb{kanji: "通る", kana: "とおる", english: "to go by", class: :godan, frequency: 4429},
    %Verb{
      kanji: "逃す",
      kana: "のがす",
      english: "to miss (e.g. a chance)",
      class: :godan,
      frequency: 4444
    },
    %Verb{kanji: "叫ぶ", kana: "さけぶ", english: "to shout", class: :godan, frequency: 4452},
    %Verb{kanji: "黙る", kana: "だまる", english: "to be silent", class: :godan, frequency: 4459},
    %Verb{kanji: "漏らす", kana: "もらす", english: "to let leak", class: :godan, frequency: 4460},
    %Verb{
      kanji: "遊ぶ",
      kana: "あそぶ",
      english: "to play (games, sports)",
      class: :godan,
      frequency: 4467
    },
    %Verb{kanji: "交える", kana: "まじえる", english: "to mix", class: :ichidan, frequency: 4470},
    %Verb{kanji: "慣れる", kana: "なれる", english: "to get used to", class: :ichidan, frequency: 4475},
    %Verb{kanji: "振る", kana: "ふる", english: "to wave", class: :godan, frequency: 4478},
    %Verb{kanji: "尽くす", kana: "つくす", english: "to use up", class: :godan, frequency: 4485},
    %Verb{kanji: "投じる", kana: "とうじる", english: "to throw", class: :ichidan, frequency: 4486},
    %Verb{
      kanji: "併せる",
      kana: "あわせる",
      english: "to match (rhythm, speed, etc.)",
      class: :ichidan,
      frequency: 4487
    },
    %Verb{kanji: "繰り広げる", kana: "くりひろげる", english: "to unfold", class: :ichidan, frequency: 4491},
    %Verb{
      kanji: "知り合う",
      kana: "しりあう",
      english: "to get to know each other",
      class: :godan,
      frequency: 4499
    },
    %Verb{kanji: "尋ねる", kana: "たずねる", english: "to ask", class: :ichidan, frequency: 4511},
    %Verb{
      kanji: "出会う",
      kana: "であう",
      english: "to meet (by chance)",
      class: :godan,
      frequency: 4515
    },
    %Verb{
      kanji: "撃つ",
      kana: "うつ",
      english: "to shoot (a gun, person, etc.)",
      class: :godan,
      frequency: 4520
    },
    %Verb{kanji: "貸す", kana: "かす", english: "to lend", class: :godan, frequency: 4521},
    %Verb{kanji: "泳ぐ", kana: "およぐ", english: "to swim", class: :godan, frequency: nil},
    %Verb{
      kanji: "勉強する",
      kana: "べんきょうする",
      english: "to study",
      class: :suru_compound,
      frequency: nil
    },
    %Verb{
      kanji: "結婚する",
      kana: "けっこんする",
      english: "to marry",
      class: :suru_compound,
      frequency: nil
    },
    %Verb{
      kanji: "旅行する",
      kana: "りょこうする",
      english: "to travel",
      class: :suru_compound,
      frequency: nil
    }
  ]

  @spec all() :: [Verb.t()]
  def all, do: @verbs

  @spec count() :: non_neg_integer()
  def count, do: length(@verbs)
end
