"""Read Anki .apkg archives into plain Python structures.

Handles all three on-disk layouts:
  * collection.anki2    - legacy, notetypes/decks stored as JSON in `col`
  * collection.anki21   - schema 11/16, same JSON-in-`col` layout
  * collection.anki21b  - zstd-compressed, normalised `notetypes`/`decks` tables

Nothing here knows about German or about the app's schema; it only turns an
.apkg into (deck_name, notetype_name, field_names, field_values, ord, due).
"""

from __future__ import annotations

import html
import json
import re
import shutil
import sqlite3
import subprocess
import tempfile
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

FIELD_SEP = "\x1f"

# Candidate collection members, most preferred first.
_COLLECTION_MEMBERS = ("collection.anki21b", "collection.anki21", "collection.anki2")

_SOUND_RE = re.compile(r"\[sound:[^\]]*\]")
_PLAY_RE = re.compile(r"\[anki:play:[^\]]*\]")
_CLOZE_RE = re.compile(r"\{\{c\d+::(.*?)(?:::.*?)?\}\}", re.DOTALL)
_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
_DROP_ELEMENT_RE = re.compile(r"<(script|style)\b.*?</\1\s*>", re.DOTALL | re.IGNORECASE)
_TAG_RE = re.compile(r"<\s*(/?)\s*([a-zA-Z0-9]+)[^>]*>")
_WS_RE = re.compile(r"[ \t\u00a0]+")
_BLANKLINES_RE = re.compile(r"\n{3,}")
_DANGLING_CELL_RE = re.compile(r"\s*\u00b7\s*(?=\n|$)")

# Tags that imply a line break where they open or close. Decks in this project
# lay out conjugation tables with <table>/<details>/<h1>, so stripping tags
# without honouring them runs whole paragraphs together into one word.
_BLOCK_TAGS = frozenset({
    "address", "article", "aside", "blockquote", "br", "caption", "details",
    "div", "dd", "dl", "dt", "fieldset", "figcaption", "figure", "footer",
    "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "li", "main",
    "nav", "ol", "p", "pre", "section", "summary", "table", "tbody", "tfoot",
    "thead", "tr", "ul",
})
# Table cells become " \u00b7 "-separated so a conjugation row stays on one line.
_CELL_TAGS = frozenset({"td", "th"})


def _tag_replacement(match: re.Match[str]) -> str:
    closing, name = match.group(1), match.group(2).lower()
    if name in _BLOCK_TAGS:
        return "\n"
    if name in _CELL_TAGS:
        return " \u00b7 " if closing else ""
    return ""


def clean_field(raw: str) -> str:
    """Turn an Anki field's HTML into display-ready plain text."""
    if not raw:
        return ""
    text = _DROP_ELEMENT_RE.sub(" ", raw)
    text = _COMMENT_RE.sub(" ", text)
    text = _SOUND_RE.sub(" ", text)
    text = _PLAY_RE.sub(" ", text)
    text = _CLOZE_RE.sub(r"\1", text)
    text = _TAG_RE.sub(_tag_replacement, text)
    text = html.unescape(text)
    text = text.replace("\u00a0", " ").replace("\r", "")
    text = _WS_RE.sub(" ", text)
    text = "\n".join(line.strip() for line in text.split("\n"))
    text = _DANGLING_CELL_RE.sub("", text)
    text = _BLANKLINES_RE.sub("\n\n", text)
    return text.strip()


def sound_refs(raw: str) -> list[str]:
    """Media filenames referenced by a field, in order."""
    return re.findall(r"\[sound:([^\]]*)\]", raw or "")


@dataclass
class AnkiCard:
    deck: str
    notetype: str
    ord: int
    guid: str
    fields: dict[str, str]          # cleaned, field name -> text
    raw_fields: dict[str, str]      # original HTML, for media/sound refs
    field_order: list[str]
    due: int = 0
    tags: str = ""


@dataclass
class AnkiCollection:
    source: Path
    cards: list[AnkiCard] = field(default_factory=list)
    media: dict[str, str] = field(default_factory=dict)  # archive member -> filename
    layout: str = ""


def _extract_collection(apkg: Path, workdir: Path) -> tuple[Path, str]:
    """Pull the best collection database out of the archive, decompressing if needed."""
    with zipfile.ZipFile(apkg) as zf:
        names = set(zf.namelist())
        member = next((m for m in _COLLECTION_MEMBERS if m in names), None)
        if member is None:
            raise ValueError(f"{apkg.name}: no collection database inside archive")
        target = workdir / member
        with zf.open(member) as src, open(target, "wb") as dst:
            shutil.copyfileobj(src, dst)

    if member.endswith(".anki21b"):
        plain = workdir / "collection.sqlite"
        # zstd whole-file stream; the CLI is used so no third-party module is required.
        subprocess.run(
            ["zstd", "-d", "-f", "-q", str(target), "-o", str(plain)],
            check=True,
            capture_output=True,
        )
        return plain, member
    return target, member


def _read_media_map(apkg: Path) -> dict[str, str]:
    with zipfile.ZipFile(apkg) as zf:
        if "media" not in zf.namelist():
            return {}
        raw = zf.read("media")
    if not raw.strip():
        return {}
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        # New-format archives store the media map as protobuf; we do not need it.
        return {}


def _has_table(con: sqlite3.Connection, name: str) -> bool:
    row = con.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone()
    return row is not None


def _normalise_deck_name(name: str) -> str:
    # New schema separates subdecks with 0x1f, the legacy JSON uses "::".
    return " :: ".join(part.strip() for part in name.replace(FIELD_SEP, "::").split("::") if part.strip())


def _load_new_schema(con: sqlite3.Connection) -> tuple[dict[int, str], dict[int, list[str]], dict[int, str]]:
    decks = {row[0]: _normalise_deck_name(row[1]) for row in con.execute("SELECT id, name FROM decks")}
    notetypes = {row[0]: row[1] for row in con.execute("SELECT id, name FROM notetypes")}
    fields: dict[int, list[str]] = {}
    for ntid, _ord, fname in con.execute("SELECT ntid, ord, name FROM fields ORDER BY ntid, ord"):
        fields.setdefault(ntid, []).append(fname)
    return decks, fields, notetypes


def _load_legacy_schema(con: sqlite3.Connection) -> tuple[dict[int, str], dict[int, list[str]], dict[int, str]]:
    models_json, decks_json = con.execute("SELECT models, decks FROM col").fetchone()
    models = json.loads(models_json)
    deck_defs = json.loads(decks_json)
    decks = {int(k): _normalise_deck_name(v["name"]) for k, v in deck_defs.items()}
    fields: dict[int, list[str]] = {}
    notetypes: dict[int, str] = {}
    for key, model in models.items():
        mid = int(key)
        notetypes[mid] = model["name"]
        fields[mid] = [f["name"] for f in sorted(model["flds"], key=lambda f: f["ord"])]
    return decks, fields, notetypes


def read_apkg(apkg: Path) -> AnkiCollection:
    """Read every card in an .apkg, resolving deck names and field names."""
    apkg = Path(apkg)
    collection = AnkiCollection(source=apkg, media=_read_media_map(apkg))

    with tempfile.TemporaryDirectory(prefix="apkg-") as tmp:
        db_path, member = _extract_collection(apkg, Path(tmp))
        collection.layout = member
        con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        con.text_factory = lambda b: b.decode("utf-8", "replace")
        try:
            if _has_table(con, "notetypes"):
                decks, fields, notetypes = _load_new_schema(con)
            else:
                decks, fields, notetypes = _load_legacy_schema(con)

            rows = con.execute(
                """
                SELECT c.did, c.ord, c.due, n.guid, n.mid, n.flds, n.tags
                FROM cards c JOIN notes n ON n.id = c.nid
                ORDER BY c.did, c.due, c.id
                """
            ).fetchall()
        finally:
            con.close()

    for did, ord_, due, guid, mid, flds, tags in rows:
        names = fields.get(mid)
        if not names:
            continue
        values = flds.split(FIELD_SEP)
        raw = {name: (values[i] if i < len(values) else "") for i, name in enumerate(names)}
        collection.cards.append(
            AnkiCard(
                deck=decks.get(did, "Default"),
                notetype=notetypes.get(mid, "Unknown"),
                ord=ord_,
                guid=guid,
                fields={k: clean_field(v) for k, v in raw.items()},
                raw_fields=raw,
                field_order=list(names),
                due=due or 0,
                tags=(tags or "").strip(),
            )
        )
    return collection
