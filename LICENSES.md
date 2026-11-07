# Licences and attribution

The app code in this repository and the bundled deck content have different
origins and different terms. This file records both.

## App code

All Dart, Kotlin, Gradle and Python source in this repository was written for
this project. Licence it as you wish.

Third-party packages are listed in `pubspec.yaml`; each carries its own licence
(all permissive: BSD-3-Clause or MIT at the time of writing).

## Deck content

Per-deck provenance is recorded in `tools/deck_sources.json`.

### Goethe A1 Wordlist — CC BY-SA 4.0 — attribution required

> "Goethe Institute A1 Wordlist" by **patsytau**
> <https://github.com/patsytau/anki_german_a1_vocab>
> Licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

Two obligations follow and both are met in this repository:

1. **Attribution.** Credit is shown in the app under Settings → Licences, and
   repeated here.
2. **ShareAlike.** The adapted form of that deck inside
   `assets/content/content.db` is offered under the same CC BY-SA 4.0 licence.
   Anyone redistributing that deck content, adapted or not, must do the same.

The upstream deck is itself derived from the Goethe-Institut's published A1
wordlist PDF. That underlying document is the Goethe-Institut's; this project
relies on the upstream author's CC BY-SA release and has not independently
verified their right to grant it.

### Textbook-derived decks — review before commercial publication

The six job and professional decks follow the vocabulary of
**"Menschen im Beruf: Bewerbungstraining"** (Hueber Verlag):

`job-nouns`, `job-verbs`, `job-adjectives`, `beruf-b2-verbs`, `beruf-it-verbs`

What ships: the German words, their English translations, articles, plurals and
conjugation tables — factual information — plus example sentences generated for
this project.

What does **not** ship, deliberately: the book's page references (`Pages`) and
`BookContext`, which held verbatim OCR'd sentences from the book. Both are
listed in `EXCLUDED_FIELDS` in `tools/mappings.py` and are filtered at build
time.

A vocabulary selection that tracks a specific textbook may still be a derived
work in some jurisdictions. Confirm this is acceptable before publishing
commercially. To ship without them, delete those five entries from
`tools/deck_sources.json` and rebuild — the app loses 5,862 cards and keeps
5,721.

### Remaining decks — own work

`core-general`, `core-speaking`, `core-it-work`, `it-verbs-families`,
`noun-adjective-families` were compiled or generated for this project.

## Audio

No audio files are bundled. Pronunciation is produced at runtime by the
device's own text-to-speech engine, so no recordings are redistributed.
