# AGENTS.md

Working notes for anyone — human or agent — changing this repository.

## What this is

**DeutschCards** is an offline Android flashcard app for learning German. It
ships 11,530 cards in 11 decks, built from Anki `.apkg` files, and pronounces
German with the device's own text-to-speech engine. Scheduling is SM-2.

- Package: `com.ekko.deutschcards`
- Flutter 3.35 / Dart 3.9, Android only (`minSdk 23`)
- No network calls, no accounts, no analytics. Everything is on-device.

## Layout

```
lib/
  srs/sm2.dart            Scheduler. Pure Dart: no I/O, no Flutter imports.
  data/
    models.dart           Deck, Flashcard, CardDetail, DeckProgress, StudyCard
    content_asset.dart    Extracts the bundled DB out of the asset bundle
    app_database.dart     The only DB connection; all SQL lives here
    content_version.dart  GENERATED - do not edit
  services/speech_service.dart   flutter_tts wrapper, German voice selection
  state/                  ChangeNotifier controllers (study, library, settings)
  ui/                     theme, screens, widgets
tools/
  anki_reader.py          Reads .apkg (all three on-disk formats)
  mappings.py             Per-notetype field mappings
  build_content.py        Builds assets/content/content.db
  deck_sources.json       Which .apkg files to import
  generate_icons.py       Launcher + Play Store icons
```

## The two databases

This is the part most likely to trip you up.

| | `content.db` | `review.db` |
|---|---|---|
| Holds | decks, notes, cards | scheduling state, review log, settings |
| Where | Flutter asset, extracted on first launch | created on device |
| Writable | never | yes |
| Replaced on app update | yes, when `content_version` changes | **never** |

`AppDatabase` opens `review.db` and **ATTACHes** `content.db` as `content`, so
queries join across both in SQLite rather than shuttling thousands of ids
through Dart. Write `content.card`, `content.note`, `content.deck` in SQL.

The link between them is `card.uid`, a hash of
`deck_slug | anki_note_guid | template_ordinal`. **Keeping uids stable is what
lets content be rebuilt without wiping anyone's progress.** If you change how
`card_uid()` is computed in `tools/build_content.py`, every user loses their
history on the next update.

## Changing deck content

Never hand-edit `assets/content/content.db`. It is generated:

```bash
python3 tools/build_content.py        # rewrites the DB and content_version.dart
flutter test                          # the DB tests run against the real file
```

To add a deck, add an entry to `tools/deck_sources.json`. If its Anki notetype
is not in `tools/mappings.py`, the build still succeeds using a two-field
fallback and **prints the notetype under "unmapped notetypes"** — add a proper
`Mapping` rather than leaving it on the fallback, or the card will show raw
field order instead of a sensible front and back.

The builder reports what it filtered (`skipped_identical`, `skipped_duplicate`).
A sudden jump in those numbers means a mapping is wrong.

`tools/deck_sources.json` also records, under `skipped`, which source files were
deliberately left out and why — check there before "fixing" a missing deck.

## Commands

```bash
flutter test                                   # 109 tests, ~15s
flutter analyze                                # must be clean
flutter run                                    # needs a device or emulator
python3 tools/build_content.py                 # rebuild deck content
python3 tools/generate_icons.py                # rebuild icons
flutter build appbundle --release              # the Play Store artifact
flutter build apk --release --split-per-abi    # for sideloading
```

## Conventions

- **`lib/srs/` stays pure.** No Flutter imports, no I/O, no `DateTime.now()`.
  `now` is always a parameter. This is why the scheduler has 27 tests that run
  instantly.
- **All SQL lives in `app_database.dart`.** Screens and controllers call
  methods, never build query strings.
- **Controllers never touch widgets**; widgets never touch SQL.
- Catch `Exception`, not `Object` — a failed review should surface a message,
  not swallow a programming error.
- Comments explain *why*. The code already says what.

## Gotchas

- **Tests and SQLite on Linux.** `flutter test` runs on the desktop, so
  `test/support/sqlite_test_setup.dart` points sqflite's FFI backend at
  `libsqlite3.so.0` (Ubuntu ships no unversioned symlink) and uses
  `databaseFactoryFfiNoIsolate` — the isolate-based factory runs SQLite where
  the loader override does not apply.
- **The asset bundle is unavailable under `flutter test`.** Database tests pass
  an `ensureContent` callback that copies `assets/content/content.db` directly.
- **TTS needs a manifest `<queries>` entry.** Android 11+ hides other packages;
  without the `TTS_SERVICE` intent in `AndroidManifest.xml`, every pronunciation
  silently fails on a real device while working fine in tests.
- **Due dates snap to midnight** so "due today" does not depend on the time of
  day. This is why `previewIntervals` reports `intervalDays` for day-based
  cards instead of the wall-clock gap.
- **Do not set `noCompress` for `db`.** The content database compresses from
  13 MB to 2 MB in the package, and it is copied out on first launch anyway.
- **Backup rules only use `<include>`.** Android lint rejects an `<exclude>`
  for a path that is not inside an included one.

## Releasing

1. Bump `version:` in `pubspec.yaml` (`1.0.0+1` → `versionName+versionCode`).
   Play rejects a bundle whose `versionCode` it has already seen.
2. Create the upload keystore once, then `android/key.properties` from
   `android/key.properties.example`. Without it the release build falls back to
   the debug key and logs a warning — such a build cannot be uploaded.
3. `flutter build appbundle --release`
4. Upload `build/app/outputs/bundle/release/app-release.aab`.

Per-device download is about 19 MB on arm64. The `.aab` on disk is larger
because it carries every ABI; Play splits it.

Store assets live in `store/` (`icon-512.png` for the listing).
