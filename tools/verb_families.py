"""Turn the IT verb-family deck's text blobs into structured cards.

The source deck stores everything it knows about a verb as one long rendered
page in the `Back` field: meaning, usage notes and the full conjugation across
five moods, all as prose. Imported verbatim that produces a "flashcard" whose
answer averages 6,600 characters and, in the worst case, 39,620 - something no
learner can grade themselves against.

This module pulls that page apart into the pieces the app already knows how to
show: a short answer, an example sentence, and labelled detail blocks.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# "Label: value" lines, in the order they should appear on the card.
INLINE_LABELS = (
    "Meaning",
    "Useful phrase",
    "Separable",
    "Reflexive pattern",
    "Principal forms",
    "Boundary and contrast",
    "Grammar in use",
    "Useful German pattern",
    "Infinitiv I",
    "Infinitiv I mit zu",
    "Infinitiv II",
    "Infinitiv II mit zu",
    "Partizip I",
    "Partizip II",
)
_LABEL_RE = re.compile(r"^(" + "|".join(re.escape(l) for l in INLINE_LABELS) + r"):\s*(.*)$")

# Mood headings introduce a run of tense tables.
MOOD_HEADINGS = (
    "Indikativ — all six tenses",
    "Konjunktiv I — all persons and tenses",
    "Konjunktiv II — simple and würde forms",
    "Imperativ, infinitives and participles",
)
TENSE_HEADINGS = (
    "Präsens", "Präteritum", "Perfekt", "Plusquamperfekt",
    "Futur I", "Futur II", "würde-Form", "Vergangenheit (würde)",
)
_PERSON_RE = re.compile(r"^(ich|du|er/sie/es|wir|ihr|sie/Sie|Sie|du \(Imperativ\)) · (.+)$")
_USAGE_RE = re.compile(r"^When can .+ fit\?\s*(.*)$")

# Short moods get a friendlier label than the source heading.
_MOOD_LABEL = {
    "Indikativ — all six tenses": "Indikativ",
    "Konjunktiv I — all persons and tenses": "Konjunktiv I",
    "Konjunktiv II — simple and würde forms": "Konjunktiv II",
    "Imperativ, infinitives and participles": "Imperativ",
}


@dataclass
class ParsedVerb:
    """One verb's page, taken apart."""

    labels: dict[str, str] = field(default_factory=dict)
    usage: str = ""
    # mood -> tense -> ["ich vertippe mich", ...]
    conjugations: dict[str, dict[str, list[str]]] = field(default_factory=dict)

    @property
    def meaning(self) -> str:
        return self.labels.get("Meaning", "")

    @property
    def phrase(self) -> str:
        return self.labels.get("Useful phrase", "")


def parse_verb_page(text: str) -> ParsedVerb:
    """Parse a rendered verb page into labelled parts and conjugation tables."""
    parsed = ParsedVerb()
    mood: str | None = None
    tense: str | None = None
    usage_parts: list[str] = []
    collecting_usage = False

    for raw in text.split("\n"):
        line = raw.strip()
        if not line:
            collecting_usage = False
            continue

        if line in MOOD_HEADINGS:
            mood, tense = _MOOD_LABEL[line], None
            collecting_usage = False
            continue

        if line in TENSE_HEADINGS:
            tense = line
            parsed.conjugations.setdefault(mood or "Formen", {}).setdefault(tense, [])
            collecting_usage = False
            continue

        person = _PERSON_RE.match(line)
        if person and mood:
            bucket = parsed.conjugations.setdefault(mood, {}).setdefault(
                tense or "Formen", []
            )
            bucket.append(person.group(2).strip())
            continue

        label = _LABEL_RE.match(line)
        if label:
            name, value = label.group(1), label.group(2).strip()
            # The page repeats some labels; the first occurrence wins.
            parsed.labels.setdefault(name, value)
            collecting_usage = False
            continue

        usage = _USAGE_RE.match(line)
        if usage:
            # The page prints the question as a heading and then repeats it at
            # the start of the answer. Keep only the answer.
            tail = usage.group(1).strip()
            if tail:
                usage_parts.append(tail)
                collecting_usage = True
            continue

        if collecting_usage:
            usage_parts.append(line)

    parsed.usage = " ".join(usage_parts).strip()
    return parsed


def conjugation_blocks(parsed: ParsedVerb) -> list[tuple[str, str]]:
    """Conjugation tables as (label, text) pairs, ready for the detail sheet."""
    blocks: list[tuple[str, str]] = []
    for mood, tenses in parsed.conjugations.items():
        for tense, forms in tenses.items():
            if not forms:
                continue
            label = tense if mood in ("Indikativ", "Formen") else f"{mood} · {tense}"
            blocks.append((label, "\n".join(forms)))
    return blocks


# --- card builders --------------------------------------------------------


def _members(card) -> list[str]:
    """Verb01..VerbNN of a family note, in order, skipping blanks."""
    out = []
    for index in range(1, 40):
        verb = card.fields.get(f"Verb{index:02d}", "").strip()
        if verb:
            out.append(verb)
    return out


def _meaning_index(ctx) -> dict[str, str]:
    """verb -> meaning, taken from the deck's individual verb notes.

    The family notes list their members by name only. Borrowing the meanings
    from the individual notes turns "tippen · vertippen · eintippen" into
    something a learner can actually be tested on.
    """
    cached = ctx.cache.get("meanings")
    if cached is not None:
        return cached

    index: dict[str, str] = {}
    for card in ctx.cards:
        if not card.notetype.startswith("German IT Individual"):
            continue
        verb = card.fields.get("Verb", "").strip()
        if not verb or verb in index:
            continue
        meaning = parse_verb_page(card.fields.get("Back", "")).meaning
        if meaning:
            index[verb] = meaning
    ctx.cache["meanings"] = index
    return index


def build_individual(card, ord_: int, ctx):
    """One IT verb: the verb on the front, its meaning on the back."""
    from mappings import DE, EN, CardParts

    verb = card.fields.get("Verb", "").strip()
    parsed = parse_verb_page(card.fields.get("Back", ""))
    meaning = parsed.meaning
    if not verb or not meaning:
        return None

    stem = card.fields.get("Stem", "").strip()
    phrase = card.fields.get("PhraseText", "").strip() or parsed.phrase

    extras: list[tuple[str, str]] = []
    if stem and stem != verb:
        extras.append(("Verb family", stem))
    for label, key in (
        ("Separable", "Separable"),
        ("Reflexive", "Reflexive pattern"),
        ("Principal forms", "Principal forms"),
    ):
        value = parsed.labels.get(key, "").strip()
        if value:
            extras.append((label, value))
    if parsed.usage:
        extras.append(("When to use it", parsed.usage))
    for label, key in (
        ("Boundary and contrast", "Boundary and contrast"),
        ("Grammar in use", "Grammar in use"),
    ):
        value = parsed.labels.get(key, "").strip()
        if value:
            extras.append((label, value))
    extras.extend(conjugation_blocks(parsed))

    return CardParts(
        front=verb,
        back=meaning,
        front_lang=DE,
        back_lang=EN,
        speak=verb,
        speak_example=phrase,
        example_de=phrase,
        extras=extras,
    )


def build_family(card, ord_: int, ctx):
    """One stem: recall the IT verbs built on it, and what they mean."""
    from mappings import DE, CardParts

    stem = card.fields.get("Stem", "").strip()
    members = _members(card)
    if not stem or len(members) < 2:
        return None

    meanings = _meaning_index(ctx)
    lines = []
    for verb in members:
        meaning = meanings.get(verb)
        lines.append(f"{verb} — {meaning}" if meaning else verb)

    return CardParts(
        # Distinguished from the individual card for the same stem, which asks
        # for a meaning rather than for the family.
        front=f"{stem} — word family",
        back="\n".join(lines),
        front_lang=DE,
        back_lang=DE,
        speak=stem,
        # Long-pressing the speaker reads the whole family, which is the point
        # of the card.
        speak_example=", ".join(members),
        extras=[("Verbs in this family", str(len(members)))],
    )
