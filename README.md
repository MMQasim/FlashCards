# DeutschCards

An offline Android flashcard app for learning German, built with Flutter.

11,549 cards across 11 decks — from Goethe-Institut A1 vocabulary through to
B2 professional and IT German — with spaced repetition and pronunciation from
the device's own text-to-speech engine.

| | |
|---|---|
| Package | `com.ekko.deutschcards` |
| Platform | Android (`minSdk 23`) |
| Download | ~19 MB on arm64 |
| Network | none — no accounts, no analytics, no permissions |

## Features

- **11 bundled decks**, selectable and tracked independently.
- **SM-2 spaced repetition** with learning steps, lapses, ease adjustment and
  interval fuzzing — the same family of algorithm Anki uses.
- **German text-to-speech** on every card, including the decks whose Anki
  source shipped no audio. Tap the speaker for the word, hold it for the
  example sentence, or have it read automatically when you reveal an answer.
- **Rich card backs**: example sentences, articles and plurals, full
  conjugation tables, usage notes and collocations, as carried by each source
  deck.
- **Search** across every card in both languages, with umlauts folded so
  `uber` finds `über` and `grosse` finds `große`.
- **Progress tracking**: streak, 30-day activity, a two-week due forecast and
  per-deck maturity.
- **Undo** for a mistyped answer, which rolls back the schedule and the log.

## The decks

| Deck | Cards | Level |
|---|---:|---|
| Goethe A1 Wordlist | 1,660 | A1 |
| Core Vocabulary: General | 1,730 | A1–B1 |
| Core Vocabulary: Speaking | 662 | A2–B1 |
| Core Vocabulary: IT & Work | 1,047 | B1–B2 |
| Job Application: Nouns | 2,458 | B1–B2 |
| Job Application: Verbs | 882 | B1–B2 |
| Job Application: Adjectives | 758 | B1–B2 |
| Berufsdeutsch B2: Verbs in Context | 882 | B2 |
| Berufsdeutsch: Verbs in IT Context | 882 | B2 |
| IT Verb Families | 488 | B2 |
| Noun & Adjective Families | 100 | B1 |

Decks with two study directions contribute one card per direction, which is
why card counts exceed word counts.

## Getting started

```bash
flutter pub get
flutter test          # 109 tests
flutter run           # with a device or emulator attached
```

## Building for release

```bash
flutter build appbundle --release
```

Signing needs `android/key.properties`; copy `android/key.properties.example`
and fill it in. Without it the build falls back to the debug key and warns —
useful for local testing, not uploadable to Play.

**[store/RELEASE.md](store/RELEASE.md)** is the step-by-step guide to getting
this on Google Play, from creating the developer account through to production.

## How the content is built

Deck content is generated from Anki `.apkg` files into a single SQLite
database that ships as an app asset:

```bash
python3 tools/build_content.py
```

The importer reads all three Anki on-disk formats (`collection.anki2`,
`.anki21`, and zstd-compressed `.anki21b`), normalises eight different
notetypes into one schema, strips the source HTML to readable plain text, and
drops duplicate and degenerate cards.

Scheduling state lives in a **separate** on-device database keyed by a stable
card id, so shipping new or corrected content never resets a learner's
progress. See [AGENTS.md](AGENTS.md#the-two-databases).

## Project layout

See [AGENTS.md](AGENTS.md#layout). Short version: `lib/srs/` is the pure
scheduler, `lib/data/` owns all SQL, `lib/state/` holds controllers, `lib/ui/`
holds screens and widgets, and `tools/` holds the Python content pipeline.

## Licensing note

The app code in this repository is yours to license as you choose. The deck
**content** is derived from third-party Anki decks; check the licence of each
source deck listed in `tools/deck_sources.json` before publishing. The
Goethe-Institut A1 wordlist deck in particular originates from a public
repository with its own licence file.
