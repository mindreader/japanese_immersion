#!/usr/bin/env python3
"""
Generate lib/japanese/drill/verbs.ex by joining JPDB frequency rankings with
JMDict POS info.

Run from the project root:

    nix shell nixpkgs#python3 --command python3 priv/drill/gen_verbs.py \\
        --jmdict /tmp/yomitan-data/jmdict-eng-common-3.6.2.json \\
        --jpdb   /tmp/yomitan-data/term_meta_bank_1.json \\
        --top    400 \\
        --out    lib/japanese/drill/verbs.ex

Source data downloads (one-time, kept out of the repo — both have their own
licenses, both are large):

    JPDB frequency:
        https://raw.githubusercontent.com/Kuuuube/yomitan-dictionaries/main/dictionaries/JPDB_v2.2_Frequency_2024-10-13.zip
        (unzip and use term_meta_bank_1.json)

    JMDict common (English):
        https://github.com/scriptin/jmdict-simplified/releases (jmdict-eng-common-*.json.tgz)

The output is hand-editable Elixir; you commit it.
"""

import argparse
import json
import sys
from pathlib import Path

# JMDict POS tag → our class atom. Skipped tags (v5aru, vz, vr, v2a-s, vs-c,
# vs-s, v5u-s) cover archaic, classical, or special verbs whose conjugations
# we don't model.
CLASS_MAP = {
    "v1": "ichidan",
    "v1-s": "ichidan",  # くれる etc. — close enough to ichidan for drill purposes
    "v5b": "godan",
    "v5g": "godan",
    "v5k": "godan",
    "v5m": "godan",
    "v5n": "godan",
    "v5r": "godan",
    "v5s": "godan",
    "v5t": "godan",
    "v5u": "godan",
    "v5k-s": "iku",
    "v5r-i": "aru",
    "vk": "kuru",
    "vs-i": "suru",
}
# NOTE: `vs` (suru-able noun) is intentionally excluded. JMDict tags many
# common nouns as `vs` to mean "can take する to become a verb"; in the freq
# data those entries are nouns, not verb conjugations. Suru-compounds get
# hand-added via SUPPLEMENT below.

# Verbs that JMDict tags with a "common" kanji form but which are written in
# kana in essentially all modern usage. Override kanji to None so the drill
# shows the form the learner will actually see in the wild.
KANA_PREFERRED = {"ある", "いる"}

# Verbs to append at the end of the generated list with frequency=None.
# Use this for verbs that fall outside top-N by JPDB freq but are still
# useful drill targets (covering rare godan rows, common N4/N5 misses, etc.).
SUPPLEMENT = [
    {"kanji": "泳ぐ", "kana": "およぐ", "english": "to swim", "class": "godan"},
    {"kanji": "勉強する", "kana": "べんきょうする", "english": "to study", "class": "suru_compound"},
    {"kanji": "結婚する", "kana": "けっこんする", "english": "to marry", "class": "suru_compound"},
    {"kanji": "旅行する", "kana": "りょこうする", "english": "to travel", "class": "suru_compound"},
]


# Sense `misc` tags that mean this is not the modern everyday reading.
# When the same kanji has multiple JMDict entries (e.g., 入る/いる literary vs
# 入る/はいる common), we deprioritize the ones tagged with any of these so
# the kanji-only fallback lookup picks the modern reading.
_DEMOTE_MISC = {"arch", "obs", "rare", "dated", "litf", "form", "obsc"}


def _is_demoted(sense):
    if any(m in _DEMOTE_MISC for m in sense.get("misc", [])):
        return True
    # JMDict's free-text `info` notes about literary/archaic usage
    info_text = " ".join(sense.get("info", [])).lower()
    return "literary" in info_text or "archaic" in info_text or "obsolete" in info_text


def load_jmdict(path):
    """Build {(kanji_or_None, kana): [(class, gloss), ...]} indexed at the
    sense level — so each (kanji, kana, POS) combination is preserved.

    This matters for verbs like 入る whose two readings (はいる godan, common
    vs いる godan, literary) live in separate JMDict entries with different
    POS tags. The sense's `appliesToKanji` and `appliesToKana` fields scope
    which readings/kanji a given POS goes with; we honour those instead of
    pairing first-kanji with first-kana. We also rank-order entries by
    "modernness" so the kanji-only fallback picks the everyday reading.
    """
    with open(path) as f:
        data = json.load(f)

    index = {}

    for word in data["words"]:
        # Word-level demotion: if the FIRST sense is tagged literary/archaic/etc,
        # treat all of this word's senses as demoted. This catches 入る/いる
        # where only the head sense carries the "literary" info note but the
        # whole word entry is the literary form.
        word_demoted = word["sense"] and _is_demoted(word["sense"][0])

        for sense in word["sense"]:
            verb_class = None
            for pos in sense["partOfSpeech"]:
                if pos in CLASS_MAP:
                    verb_class = CLASS_MAP[pos]
                    break
            if not verb_class:
                continue

            demoted = word_demoted or _is_demoted(sense)

            gloss = None
            for g in sense.get("gloss", []):
                if g.get("lang") == "eng" and g.get("text"):
                    gloss = g["text"]
                    break
            if not gloss:
                continue

            applies_kanji = sense.get("appliesToKanji", ["*"])
            applies_kana = sense.get("appliesToKana", ["*"])

            # Common kanji this sense applies to
            kanji_forms = [
                k["text"]
                for k in word["kanji"]
                if k.get("common") and (applies_kanji == ["*"] or k["text"] in applies_kanji)
            ]
            # Common kana this sense applies to
            kana_forms = [
                k["text"]
                for k in word["kana"]
                if k.get("common") and (applies_kana == ["*"] or k["text"] in applies_kana)
            ]
            # Fall back to non-common kana if no common form applies — keeps verbs
            # like ある (kana not always tagged common) in the index
            if not kana_forms:
                kana_forms = [
                    k["text"]
                    for k in word["kana"]
                    if applies_kana == ["*"] or k["text"] in applies_kana
                ]

            if kanji_forms:
                for kj in kanji_forms:
                    valid_kana = [
                        kn
                        for k in word["kana"]
                        if (kn := k["text"]) in kana_forms
                        and (
                            k.get("appliesToKanji", ["*"]) == ["*"]
                            or kj in k.get("appliesToKanji", [])
                        )
                    ]
                    for kn in valid_kana:
                        index.setdefault((kj, kn), []).append((verb_class, gloss))
                        # Kanji-only fallback: store with demotion flag so we
                        # can stable-sort after all senses are collected.
                        index.setdefault((kj, None), []).append(
                            (demoted, verb_class, kn, gloss)
                        )
            else:
                for kn in kana_forms:
                    index.setdefault((None, kn), []).append((verb_class, gloss))

    # Stable sort kanji-only fallback so non-demoted senses come first while
    # preserving JMDict's primary-sense-first ordering within each group.
    for key in list(index.keys()):
        if key[1] is None:
            sorted_records = sorted(index[key], key=lambda r: r[0])
            index[key] = [(cls, kn, gl) for _, cls, kn, gl in sorted_records]

    return index


def load_jpdb_freq(path):
    """Yield (term, reading_or_None, rank) in ascending rank order.

    The same term often appears multiple times with different ranks (one per
    POS interpretation). We deduplicate by term, picking the entry that has
    a reading if any exists, and among equally-qualifying entries the lowest
    rank wins.
    """
    with open(path) as f:
        entries = json.load(f)

    best = {}  # term → (reading_or_None, rank)
    for entry in entries:
        term = entry[0]
        meta = entry[2]
        if not isinstance(meta, dict):
            continue
        if "frequency" in meta:
            rank = meta["frequency"]["value"]
            reading = meta.get("reading")
        elif "value" in meta:
            rank = meta["value"]
            reading = None
        else:
            continue

        if term not in best:
            best[term] = (reading, rank)
        else:
            old_reading, old_rank = best[term]
            # Prefer entries with reading; among entries of same reading-status,
            # take the lowest rank
            if reading and not old_reading:
                best[term] = (reading, rank)
            elif (reading and old_reading) or (not reading and not old_reading):
                if rank < old_rank:
                    best[term] = (reading, rank)

    out = [(t, r, rank) for t, (r, rank) in best.items()]
    out.sort(key=lambda x: x[2])
    return out


def looks_like_kana(s):
    return all("぀" <= c <= "ゟ" or "゠" <= c <= "ヿ" for c in s)


def join(jmdict_index, jpdb_freq, top_n):
    seen = set()
    results = []

    for term, reading, rank in jpdb_freq:
        # Build lookup key from JPDB's term + reading
        if looks_like_kana(term):
            key = (None, term)
            records = jmdict_index.get(key)
            if not records:
                continue
            verb_class, gloss = records[0]
            kanji, kana = None, term
        elif reading:
            key = (term, reading)
            records = jmdict_index.get(key)
            if records:
                verb_class, gloss = records[0]
                kanji, kana = term, reading
            else:
                # Reading didn't match any sense — fall back to kanji-only lookup
                records = jmdict_index.get((term, None))
                if not records:
                    continue
                verb_class, fallback_kana, gloss = records[0]
                kanji, kana = term, fallback_kana
        else:
            # Kanji term, no reading from JPDB — use kanji-only fallback
            records = jmdict_index.get((term, None))
            if not records:
                continue
            verb_class, fallback_kana, gloss = records[0]
            kanji, kana = term, fallback_kana

        # Apply kana-preferred override for verbs canonically written in kana.
        if kana in KANA_PREFERRED:
            kanji = None

        dedup_key = (kanji, kana)
        if dedup_key in seen:
            continue
        seen.add(dedup_key)

        results.append({
            "kanji": kanji,
            "kana": kana,
            "english": gloss,
            "class": verb_class,
            "frequency": rank,
        })

        if len(results) >= top_n:
            break

    # Append supplement verbs (no JPDB rank). Skip if already present.
    for sup in SUPPLEMENT:
        if (sup["kanji"], sup["kana"]) in seen or (None, sup["kana"]) in seen:
            continue
        results.append({
            "kanji": sup["kanji"],
            "kana": sup["kana"],
            "english": sup["english"],
            "class": sup["class"],
            "frequency": None,
        })

    return results


def to_elixir(verbs):
    """Render a list of verb dicts as the contents of verbs.ex."""
    lines = [
        "defmodule Japanese.Drill.Verbs do",
        '  @moduledoc """',
        "  Verb list for the drill mode — generated from JPDB frequency rankings",
        "  joined with JMDict-common POS information. Re-generate with",
        "  `priv/drill/gen_verbs.py`.",
        "",
        "  Ordered by JPDB frequency rank ascending. The `frequency` field is",
        "  the JPDB rank — lower numbers mean more common.",
        "",
        "  Class is stored explicitly because kana endings alone can't",
        "  distinguish godan 切る (kiru, to cut) from ichidan 着る (kiru, to",
        "  wear). Edit freely — this file is hand-committed.",
        '  """',
        "",
        "  alias Japanese.Drill.Verb",
        "",
        "  @verbs [",
    ]

    for i, v in enumerate(verbs):
        kanji = f'"{v["kanji"]}"' if v["kanji"] else "nil"
        english = v["english"].replace('\\', '\\\\').replace('"', '\\"')
        freq = "nil" if v["frequency"] is None else str(v["frequency"])
        last = "" if i == len(verbs) - 1 else ","
        lines.append(
            f'    %Verb{{kanji: {kanji}, kana: "{v["kana"]}", '
            f'english: "{english}", class: :{v["class"]}, '
            f'frequency: {freq}}}{last}'
        )

    lines += [
        "  ]",
        "",
        "  @spec all() :: [Verb.t()]",
        "  def all, do: @verbs",
        "",
        "  @spec count() :: non_neg_integer()",
        "  def count, do: length(@verbs)",
        "end",
        "",
    ]
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jmdict", required=True, help="jmdict-eng-common JSON")
    ap.add_argument("--jpdb", required=True, help="JPDB term_meta_bank_1.json")
    ap.add_argument("--top", type=int, default=400, help="how many verbs to keep")
    ap.add_argument("--out", required=True, help="output Elixir file")
    args = ap.parse_args()

    print(f"Loading JMDict from {args.jmdict}…", file=sys.stderr)
    jmdict = load_jmdict(args.jmdict)
    print(f"  {len(jmdict)} keys indexed", file=sys.stderr)

    print(f"Loading JPDB freq from {args.jpdb}…", file=sys.stderr)
    freq = load_jpdb_freq(args.jpdb)
    print(f"  {len(freq)} entries", file=sys.stderr)

    print(f"Joining → top {args.top} verbs…", file=sys.stderr)
    verbs = join(jmdict, freq, args.top)
    print(f"  produced {len(verbs)} verbs", file=sys.stderr)

    Path(args.out).write_text(to_elixir(verbs))
    print(f"Wrote {args.out}", file=sys.stderr)

    # Class breakdown for sanity
    counts = {}
    for v in verbs:
        counts[v["class"]] = counts.get(v["class"], 0) + 1
    print("Class breakdown:", counts, file=sys.stderr)


if __name__ == "__main__":
    main()
