defmodule Japanese.Drill.Verb do
  @moduledoc """
  A drillable Japanese verb.

  `kanji` is the form written with its standard kanji (e.g., "買う"). It may be
  `nil` for verbs that are conventionally written in kana (e.g., ある).

  `kana` is the dictionary form fully in hiragana — also what the conjugator
  uses to derive godan endings.

  `class` selects the conjugation algorithm. For godan verbs the row is derived
  from the final kana of `kana`; we still store `:godan` explicitly so that
  ambiguous cases (e.g., 切る godan vs 着る ichidan) are unambiguous.
  """

  @type class :: :godan | :ichidan | :suru | :kuru | :iku | :aru | :suru_compound

  @enforce_keys [:kana, :english, :class]
  defstruct [:kanji, :kana, :english, :class, :frequency]

  @type t :: %__MODULE__{
          kanji: String.t() | nil,
          kana: String.t(),
          english: String.t(),
          class: class(),
          frequency: pos_integer() | nil
        }
end
