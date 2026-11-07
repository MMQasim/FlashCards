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

from dataclasses import dataclass, field as dc_field

DE = "de"
EN = "en"

# Fields that only ever hold media filenames or bookkeeping, never shown.
NOISE_FIELDS = {"Audio", "EnglishAudio", "NounAudio", "AdjectiveAudio",
                "ComparativeAudio", "SuperlativeAudio", "Note ID", "Version",
                "de_audio", "Set", "Priority", "VerbCount", "Stem"}
NOISE_PREFIXES = ("Audio", "AudioText")


@dataclass(frozen=True)
class Direction:
    """One studiable direction of a note."""
    front: tuple[str, ...]
    back: tuple[str, ...]
    front_lang: str
    back_lang: str


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
    "Differences", "BookContext",
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
_register(Mapping(
    notetype="German IT Verb Family V6 Separate Audio",
    directions={0: _d("Front", "Back", DE, EN)},
    speak=("Front",),
    extras="*",
))
_register(Mapping(
    notetype="German IT Individual Verb V6 Audio Fields",
    directions={0: _d("Front", "Back", DE, EN)},
    speak=("Front",),
    extras="*",
))


def fallback_mapping(notetype: str, field_order: list[str]) -> Mapping:
    """Treat an unknown notetype as a plain two-field card.

    Keeps unrecognised decks importable instead of silently dropping them; the
    build report flags every notetype that lands here so the mapping can be
    added deliberately.
    """
    usable = [f for f in field_order if f not in NOISE_FIELDS]
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
        if name not in field_order or name in out:
            continue
        out.append(name)
    return out
