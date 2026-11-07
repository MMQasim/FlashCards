"""Per-notetype field mappings: Anki fields -> DeutschCards card columns.

Every Anki notetype in the source decks names its fields differently, so each
one gets a `Mapping` describing which field is the prompt, which is the answer,
which German string to hand to text-to-speech, and which remaining fields are
worth showing on the detail sheet.

`directions` is keyed by the Anki template ordinal, because Anki already
generates one card row per template - ordinal 0 is usually German -> English and
ordinal 1 the reverse. Honouring the ordinal means the card counts in the app
match the card counts in Anki.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass, field as dc_field

DE = "de"
EN = "en"

# Fields that only ever hold media filenames or bookkeeping, never shown.
NOISE_FIELDS = {"Audio", "EnglishAudio", "NounAudio", "AdjectiveAudio",
                "ComparativeAudio", "SuperlativeAudio", "Note ID", "Version",
                "de_audio", "Set", "Priority", "VerbCount", "Stem"}

# Fields deliberately never shipped, for rights reasons rather than usefulness.
#
# "Pages" and "BookContext" come from the Hueber textbook the source decks were
# built against. BookContext in particular holds verbatim OCR'd sentences from
# that book, OCR errors and page numbers included - reproducing them in a
# published app would be redistributing copyrighted text. The generated example
# sentences carry the same teaching value without the problem.
EXCLUDED_FIELDS = {"Pages", "BookContext"}
NOISE_PREFIXES = ("Audio", "AudioText")


@dataclass(frozen=True)
class Direction:
    """One studiable direction of a note."""
    front: tuple[str, ...]
    back: tuple[str, ...]
    front_lang: str
    back_lang: str


@dataclass
class CardParts:
    """A finished card, for notetypes that need more than field selection."""

    front: str
    back: str
    front_lang: str = DE
    back_lang: str = EN
    speak: str = ""
    speak_example: str = ""
    example_de: str = ""
    example_en: str = ""
    extras: list[tuple[str, str]] = dc_field(default_factory=list)


@dataclass
class BuildContext:
    """Whole-deck data a custom builder may need, computed once per deck."""

    cards: list = dc_field(default_factory=list)
    cache: dict = dc_field(default_factory=dict)


@dataclass
class Mapping:
    notetype: str
    directions: dict[int, Direction]
    speak: tuple[str, ...] = ()           # German term to pronounce
    speak_example: str | None = None      # German sentence to pronounce
    example_de: str | None = None
    example_en: str | None = None
    extras: tuple[str, ...] | str = ()    # explicit field list, or "*" for the rest
    extra_skip: tuple[str, ...] = ()
    reverse_is_recognition: bool = True

    # Some notetypes store everything as one rendered page rather than in
    # separate fields; those supply a builder instead of a field selection.
    # Returning None drops the card.
    build: Callable[[object, int, "BuildContext"], "CardParts | None"] | None = None


def _d(front, back, front_lang, back_lang) -> Direction:
    as_tuple = lambda v: (v,) if isinstance(v, str) else tuple(v)
    return Direction(as_tuple(front), as_tuple(back), front_lang, back_lang)


MAPPINGS: dict[str, Mapping] = {}


def _register(m: Mapping) -> None:
    MAPPINGS[m.notetype] = m


# --- Goethe-Institut A1 wordlist -------------------------------------------
_register(Mapping(
    notetype="Goethe Vocab List",
    directions={
        0: _d("de_word", "en_word", DE, EN),
        1: _d("en_word", "de_word", EN, DE),
    },
    speak=("de_word",),
    speak_example="de_sentence",
    example_de="de_sentence",
    example_en="en_sentence",
    extras=("en_note",),
))

# --- German 3500 core vocabulary (single English -> German template) -------
_register(Mapping(
    notetype="German Vocabulary — English to German + Audio",
    directions={
        0: _d("English", ("Article", "German"), EN, DE),
    },
    speak=("Article", "German"),
    extras=("Part_of_Speech",),
))

# --- Bewerbungstraining: nouns --------------------------------------------
_register(Mapping(
    notetype="Bewerbungstraining Noun",
    directions={
        0: _d("GermanNoun", "English", DE, EN),
        1: _d("English", "GermanNoun", EN, DE),
    },
    speak=("GermanNoun",),
    speak_example="ExampleGerman",
    example_de="ExampleGerman",
    example_en="ExampleEnglish",
    extras=("Article", "Plural"),
))

# --- Bewerbungstraining: adjectives ---------------------------------------
_register(Mapping(
    notetype="Bewerbungstraining Adjective",
    directions={
        0: _d("Adjective", "English", DE, EN),
        1: _d("English", "Adjective", EN, DE),
    },
    speak=("Adjective",),
    speak_example="ExampleGerman",
    example_de="ExampleGerman",
    example_en="ExampleEnglish",
    extras=("Comparative", "Superlative"),
))

# --- Verb notetypes -------------------------------------------------------
# Bewerbungstraining, B2 Berufsdeutsch and Deutsch im Beruf share a field
# vocabulary; the richer ones simply add context fields on top.
_VERB_EXTRAS = (
    "CoreMeaning", "VerbType", "Auxiliary", "Reflexive", "GrammarPattern",
    "Present", "Preterite", "ParticipleII", "Perfect", "Pluperfect",
    "FutureI", "FutureII", "Imperatives", "UseWhen", "AvoidWhen",
    "TypicalCombinations", "TechnicalCombinations", "SimilarVerbs",
    "Differences",
    # "BookContext" is intentionally absent - see EXCLUDED_FIELDS.
)

for _verb_notetype in (
    "Bewerbungstraining Verb",
    "B2 Berufsdeutsch – Verben im Kontext – Vollständig",
    "Deutsch im Beruf – Verben: Gebrauch & IT-Kontext",
    "Deutsch im Beruf – Verb im Kontext",
):
    _register(Mapping(
        notetype=_verb_notetype,
        directions={
            0: _d("Infinitive", "English", DE, EN),
            1: _d("English", "Infinitive", EN, DE),
        },
        speak=("Infinitive",),
        speak_example="ProfessionalExample",
        example_de="ExampleGerman",
        example_en="ExampleEnglish",
        extras=_VERB_EXTRAS + ("ProfessionalExample", "ProfessionalExampleEnglish"),
    ))

# --- Noun/adjective families ----------------------------------------------
_register(Mapping(
    notetype="German Noun + Adjective + Comparative + Superlative",
    directions={
        0: _d("English", ("Noun", "Adjective"), EN, DE),
    },
    speak=("Noun",),
    extras=("Noun", "Adjective", "Comparative", "Superlative"),
))

# --- IT verb families (newer deck, two notetypes) -------------------------
# Both store their content as one rendered page in `Back`, so they are built by
# tools/verb_families.py rather than by selecting fields. Imported as-is they
# produce answers averaging 6,600 characters.
_register(Mapping(
    notetype="German IT Verb Family V6 Separate Audio",
    directions={0: _d("Front", "Back", DE, EN)},
    build=lambda card, ord_, ctx: _verb_families().build_family(card, ord_, ctx),
))
_register(Mapping(
    notetype="German IT Individual Verb V6 Audio Fields",
    directions={0: _d("Front", "Back", DE, EN)},
    build=lambda card, ord_, ctx: _verb_families().build_individual(card, ord_, ctx),
))


def _verb_families():
    """Imported lazily so mappings.py stays importable on its own."""
    import verb_families

    return verb_families


def fallback_mapping(notetype: str, field_order: list[str]) -> Mapping:
    """Treat an unknown notetype as a plain two-field card.

    Keeps unrecognised decks importable instead of silently dropping them; the
    build report flags every notetype that lands here so the mapping can be
    added deliberately.
    """
    usable = [f for f in field_order
              if f not in NOISE_FIELDS and f not in EXCLUDED_FIELDS]
    front = usable[0] if usable else (field_order[0] if field_order else "Front")
    back = usable[1] if len(usable) > 1 else front
    return Mapping(
        notetype=notetype,
        directions={
            0: _d(front, back, DE, EN),
            1: _d(back, front, EN, DE),
        },
        speak=(front,),
        extras="*",
    )


# Field names are written for the deck author, not the learner: "CoreMeaning",
# "ParticipleII", "Part_of_Speech". These turn them into labels a reader
# expects, splitting camel case and numbers while leaving roman numerals alone.
_CAMEL_BOUNDARY = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")
_ACRONYM_BOUNDARY = re.compile(r"(?<=[A-Z])(?=[A-Z][a-z])")
_NUMBER_BOUNDARY = re.compile(r"(?<=[A-Za-z])(?=\d)")


def humanise_label(name: str) -> str:
    """Turn a notetype field name into a label for display."""
    text = name.replace("_", " ")
    text = _CAMEL_BOUNDARY.sub(" ", text)
    text = _ACRONYM_BOUNDARY.sub(" ", text)
    text = _NUMBER_BOUNDARY.sub(" ", text)

    words = [w for w in text.split() if w]
    if not words:
        return name

    out = [words[0][:1].upper() + words[0][1:]]
    for word in words[1:]:
        if word.isdigit():
            # "Verb 01" reads better as "Verb 1".
            out.append(str(int(word)))
        elif word.isupper():
            # Roman numerals and acronyms keep their case: "Participle II".
            out.append(word)
        else:
            out.append(word.lower())
    return " ".join(out)


def resolve_extras(mapping: Mapping, field_order: list[str], used: set[str]) -> list[str]:
    """Which field names belong on the detail sheet, in display order."""
    if mapping.extras == "*":
        candidates = field_order
    else:
        candidates = list(mapping.extras)
    out: list[str] = []
    for name in candidates:
        if name in used or name in mapping.extra_skip:
            continue
        if name in NOISE_FIELDS or name.startswith(NOISE_PREFIXES):
            continue
        if name in EXCLUDED_FIELDS:
            continue
        if name not in field_order or name in out:
            continue
        out.append(name)
    return out
