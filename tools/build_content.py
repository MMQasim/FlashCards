#!/usr/bin/env python3
"""Build the bundled content database from the source Anki decks.

    python3 tools/build_content.py [--manifest tools/deck_sources.json]
                                   [--out assets/content/content.db]

The output is committed to the repository so that a release build never needs
the original .apkg files. Review progress lives in a separate database on the
device keyed by `card.uid`, so rebuilding content never resets a user's streak
as long as the source notes keep their Anki GUIDs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from anki_reader import AnkiCard, read_apkg  # noqa: E402
from mappings import (  # noqa: E402
    MAPPINGS,
    BuildContext,
    CardParts,
    Mapping,
    fallback_mapping,
    humanise_label,
    resolve_extras,
)

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_VERSION = 1

SCHEMA = """
PRAGMA journal_mode = DELETE;
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE deck (
  id          INTEGER PRIMARY KEY,
  slug        TEXT    NOT NULL UNIQUE,
  name        TEXT    NOT NULL,
  level       TEXT,
  description TEXT,
  card_count  INTEGER NOT NULL DEFAULT 0,
  sort_order  INTEGER NOT NULL DEFAULT 0
);
-- One row per source Anki note. Everything that both study directions share
-- lives here so the conjugation tables are not stored twice.
CREATE TABLE note (
  id            INTEGER PRIMARY KEY,
  deck_id       INTEGER NOT NULL REFERENCES deck(id),
  speak_text    TEXT,
  speak_example TEXT,
  example_de    TEXT,
  example_en    TEXT,
  extras        TEXT,
  tags          TEXT
);
-- One row per studiable direction.
CREATE TABLE card (
  id         INTEGER PRIMARY KEY,
  uid        TEXT    NOT NULL UNIQUE,
  note_id    INTEGER NOT NULL REFERENCES note(id),
  deck_id    INTEGER NOT NULL REFERENCES deck(id),
  front      TEXT    NOT NULL,
  back       TEXT    NOT NULL,
  front_lang TEXT    NOT NULL,
  back_lang  TEXT    NOT NULL,
  search     TEXT    NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
);
-- Substring search cannot use a B-tree index, so `search` is deliberately
-- unindexed; an 11k-row scan is well under a frame budget.
CREATE INDEX card_deck_idx ON card(deck_id, sort_order);
CREATE INDEX note_deck_idx ON note(deck_id);
"""


# Folded so that searching "grosse" finds "große" and "uber" finds "über".
_FOLD = str.maketrans({
    "ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss",
    "Ä": "ae", "Ö": "oe", "Ü": "ue",
    "é": "e", "è": "e", "ê": "e", "á": "a", "à": "a", "â": "a",
    "í": "i", "ì": "i", "ó": "o", "ò": "o", "ô": "o", "ú": "u", "ù": "u",
    "ç": "c", "ñ": "n",
})


def fold(text: str) -> str:
    """Normalise text for diacritic-insensitive substring search."""
    return text.casefold().translate(_FOLD)


# At least one letter or digit. Some source notes use a bare ellipsis where a
# single-word translation does not exist ("…" against "der Schluss"), which
# produces a card whose prompt carries no information at all.
_MEANINGFUL_RE = re.compile(r"[^\W_]", re.UNICODE)


def is_meaningful(text: str) -> bool:
    """Whether a card side actually says something the learner can answer."""
    return bool(_MEANINGFUL_RE.search(text))


def join_fields(card: AnkiCard, names: tuple[str, ...]) -> str:
    """Join several fields into one card side, without repeating a part.

    Some decks store the article both in its own field and inline in the noun
    ("Article: die", "German: die Arbeit"). Joining those blindly produces
    "die die Arbeit", so a part that the next one already starts with is
    dropped.
    """
    parts = [card.fields.get(n, "").strip() for n in names]
    parts = [p for p in parts if p]

    kept: list[str] = []
    for index, part in enumerate(parts):
        following = parts[index + 1] if index + 1 < len(parts) else ""
        if following.casefold().startswith(part.casefold() + " "):
            continue
        kept.append(part)
    return " ".join(kept).strip()


def card_uid(deck_slug: str, guid: str, ord_: int) -> str:
    digest = hashlib.sha1(f"{deck_slug}|{guid}|{ord_}".encode("utf-8")).hexdigest()
    return digest[:20]


def build_rows(deck_cfg: dict, collection, report: Counter, unknown: set[str]) -> list[dict]:
    slug = deck_cfg["slug"]
    context = BuildContext(cards=collection.cards)
    rows: list[dict] = []
    seen_uids: set[str] = set()
    seen_pairs: set[tuple[str, str]] = set()

    for index, card in enumerate(collection.cards):
        mapping: Mapping | None = MAPPINGS.get(card.notetype)
        if mapping is None:
            unknown.add(f"{slug}: {card.notetype}")
            mapping = fallback_mapping(card.notetype, card.field_order)

        direction = mapping.directions.get(card.ord)
        if direction is None:
            # Anki generated a template this mapping does not describe (for
            # example a cloze sibling); skipping avoids duplicate prompts.
            report["skipped_unmapped_template"] += 1
            continue

        built: CardParts | None = None
        if mapping.build is not None:
            built = mapping.build(card, card.ord, context)
            if built is None:
                report["skipped_by_builder"] += 1
                continue

        front = built.front if built else join_fields(card, direction.front)
        back = built.back if built else join_fields(card, direction.back)
        if not front or not back:
            report["skipped_empty"] += 1
            continue
        if not is_meaningful(front) or not is_meaningful(back):
            report["skipped_placeholder"] += 1
            continue
        if front == back:
            report["skipped_identical"] += 1
            continue

        pair = (front.casefold(), back.casefold())
        if pair in seen_pairs:
            report["skipped_duplicate"] += 1
            continue
        seen_pairs.add(pair)

        uid = card_uid(slug, card.guid, card.ord)
        if uid in seen_uids:
            report["skipped_uid_clash"] += 1
            continue
        seen_uids.add(uid)

        # A detail that merely restates the card's own front or back is noise;
        # "CoreMeaning: break off / discontinue" under the answer
        # "break off / discontinue" tells the learner nothing.
        shown = {front.casefold(), back.casefold()}

        if built:
            extras = [
                {"label": label, "value": value}
                for label, value in built.extras
                if value.strip() and value.strip().casefold() not in shown
            ]
            speak_text = built.speak
            speak_example = built.speak_example
            example_de = built.example_de
            example_en = built.example_en
            front_lang, back_lang = built.front_lang, built.back_lang
        else:
            used = set(direction.front) | set(direction.back)
            for name in (mapping.example_de, mapping.example_en, mapping.speak_example):
                if name:
                    used.add(name)
            used |= set(mapping.speak)

            extras = [
                {"label": humanise_label(name), "value": card.fields[name]}
                for name in resolve_extras(mapping, card.field_order, used)
                if card.fields.get(name, "").strip()
                and card.fields[name].strip().casefold() not in shown
            ]
            speak_text = join_fields(card, mapping.speak) or (
                front if direction.front_lang == "de" else back
            )
            speak_example = (
                card.fields.get(mapping.speak_example, "") if mapping.speak_example else ""
            )
            example_de = card.fields.get(mapping.example_de, "") if mapping.example_de else ""
            example_en = card.fields.get(mapping.example_en, "") if mapping.example_en else ""
            front_lang, back_lang = direction.front_lang, direction.back_lang

        rows.append({
            "note_key": card.guid,
            "uid": uid,
            "front": front,
            "back": back,
            "front_lang": front_lang,
            "back_lang": back_lang,
            "search": fold(f"{front}\n{back}"),
            "sort_order": card.due if card.due and card.due < 10**6 else index,
            "note": {
                "speak_text": speak_text or None,
                "speak_example": speak_example or None,
                "example_de": example_de or None,
                "example_en": example_en or None,
                "extras": json.dumps(extras, ensure_ascii=False) if extras else None,
                "tags": card.tags or None,
            },
        })
    return rows


def resolve_path(raw: str) -> Path:
    path = Path(raw)
    return path if path.is_absolute() else (REPO_ROOT / path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default="tools/deck_sources.json")
    parser.add_argument("--out", default="assets/content/content.db")
    args = parser.parse_args()

    manifest_path = resolve_path(args.manifest)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    out_path = resolve_path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()

    con = sqlite3.connect(out_path)
    con.executescript(SCHEMA)

    report = Counter()
    unknown: set[str] = set()
    fingerprint = hashlib.sha256()
    total_cards = 0
    deck_count = 0

    for deck_cfg in manifest["decks"]:
        source = resolve_path(deck_cfg["path"])
        if not source.exists():
            print(f"  !! missing source, deck skipped: {source}", file=sys.stderr)
            report["missing_source"] += 1
            continue

        collection = read_apkg(source)
        rows = build_rows(deck_cfg, collection, report, unknown)
        if not rows:
            print(f"  !! no usable cards in {source.name}", file=sys.stderr)
            continue

        cur = con.execute(
            "INSERT INTO deck (slug, name, level, description, card_count, sort_order)"
            " VALUES (?,?,?,?,?,?)",
            (deck_cfg["slug"], deck_cfg["name"], deck_cfg.get("level"),
             deck_cfg.get("description"), len(rows), deck_cfg.get("sort_order", 0)),
        )
        deck_id = cur.lastrowid

        note_ids: dict[str, int] = {}
        for r in rows:
            key = r["note_key"]
            if key not in note_ids:
                note_ids[key] = con.execute(
                    "INSERT INTO note (deck_id, speak_text, speak_example, example_de,"
                    " example_en, extras, tags)"
                    " VALUES (:deck_id,:speak_text,:speak_example,:example_de,"
                    ":example_en,:extras,:tags)",
                    dict(r["note"], deck_id=deck_id),
                ).lastrowid

        con.executemany(
            "INSERT INTO card (uid, note_id, deck_id, front, back, front_lang,"
            " back_lang, search, sort_order)"
            " VALUES (:uid,:note_id,:deck_id,:front,:back,:front_lang,"
            ":back_lang,:search,:sort_order)",
            [{k: r[k] for k in ("uid", "front", "back", "front_lang", "back_lang",
                                "search", "sort_order")}
             | {"deck_id": deck_id, "note_id": note_ids[r["note_key"]]}
             for r in rows],
        )

        for r in sorted(rows, key=lambda r: r["uid"]):
            fingerprint.update(f"{r['uid']}{r['front']}{r['back']}".encode("utf-8"))

        total_cards += len(rows)
        deck_count += 1
        print(f"  {deck_cfg['slug']:<26} {len(rows):>5} cards  "
              f"({collection.layout}, {len(collection.cards)} anki cards)")

    con.executemany(
        "INSERT INTO meta (key, value) VALUES (?,?)",
        [
            ("schema_version", str(SCHEMA_VERSION)),
            ("content_version", fingerprint.hexdigest()[:16]),
            ("card_count", str(total_cards)),
        ],
    )
    con.commit()
    con.execute("VACUUM")
    con.close()

    version_dart = REPO_ROOT / "lib" / "data" / "content_version.dart"
    version_dart.parent.mkdir(parents=True, exist_ok=True)
    version_dart.write_text(
        "// GENERATED by tools/build_content.py - do not edit by hand.\n"
        "//\n"
        "// The app compares `bundledContentVersion` against the marker file beside\n"
        "// its copy of the database to decide whether to re-extract the asset.\n"
        "library;\n\n"
        f"const String bundledContentVersion = '{fingerprint.hexdigest()[:16]}';\n"
        f"const int bundledContentSchemaVersion = {SCHEMA_VERSION};\n"
        f"const int bundledCardCount = {total_cards};\n"
        f"const int bundledDeckCount = {deck_count};\n",
        encoding="utf-8",
    )
    print(f"  wrote {version_dart.relative_to(REPO_ROOT)}")

    print(f"\n{total_cards} cards across {len(manifest['decks'])} decks "
          f"-> {out_path.relative_to(REPO_ROOT)} ({out_path.stat().st_size / 1024:.0f} KiB)")
    if report:
        print("filtered:", dict(report))
    if unknown:
        print("unmapped notetypes (used fallback mapping):")
        for item in sorted(unknown):
            print("   -", item)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
