# Play Store listing — draft

Copy for the Play Console. Review before submitting; the content-rights and
data-safety answers are assertions you are making to Google.

## App name (30 characters max)

```
DeutschCards: German Flashcards
```
(31 characters — trim to `DeutschCards — Learn German` if rejected.)

## Short description (80 characters max)

```
Learn German offline with 11,500 flashcards, spaced repetition and audio.
```

## Full description (4000 characters max)

```
DeutschCards helps you build real German vocabulary and keep it.

Over 11,500 cards across 11 decks take you from your first hundred words to
professional and technical German. Everything is on your device, so it works
on a plane, on the underground, and anywhere else you actually have a spare
five minutes.

SPACED REPETITION THAT RESPECTS YOUR TIME
Each card comes back exactly when you are about to forget it. Rate how well you
recalled it and the app schedules the next review — minutes for something new,
months for something you know cold. You see far fewer cards than a fixed-review
app and remember more.

HEAR EVERY WORD
German pronunciation on every card, using your phone's own speech engine. Tap
the speaker to hear the word, hold it to hear the full example sentence, or let
the app read the answer aloud automatically as you reveal it.

VOCABULARY FOR WHERE YOU ARE
• Goethe A1 wordlist with example sentences, for your first exam
• High-frequency everyday German, ordered by how useful each word is
• Speaking and personal topics for conversation
• IT and workplace vocabulary
• Job application German: nouns with articles and plurals, adjectives with
  comparatives, verbs with complete conjugation tables
• B2 professional verbs with usage notes, patterns and collocations
• IT verb families, so you learn a stem and its prefixes together

MORE THAN A WORD AND A TRANSLATION
Cards carry what you actually need: the article and plural for every noun, full
conjugations across every tense for verbs, comparatives and superlatives for
adjectives, example sentences in both languages, and notes on when to use a
word and when not to.

LOOK ANYTHING UP
Search every card in German or English. Umlauts are optional — type "uber" and
you will find "über".

SEE YOUR PROGRESS
A daily streak, thirty days of activity, a two-week forecast of what is coming,
and per-deck progress towards knowing each word for good.

PRIVATE BY DESIGN
No account. No ads. No tracking. No internet permission. Nothing you study
leaves your phone.
```

## Category and tags

- Category: **Education**
- Tags: Language learning, German, Flashcards, Vocabulary

## Content rating questionnaire

Educational app, no user-generated content, no ads, no in-app purchases, no
data collection. Expect **Everyone / PEGI 3**.

## Data safety form

- Does your app collect or share any required user data? **No**
- Is all user data encrypted in transit? Not applicable (no data transmitted)
- Do you provide a way for users to request data deletion? Data never leaves
  the device; "Reset progress" per deck is in the app.

## Required graphical assets

| Asset | Requirement | Status |
|---|---|---|
| App icon | 512 × 512 PNG, 32-bit | `store/icon-512.png` ✅ |
| Feature graphic | 1024 × 500 PNG/JPG | `store/feature-graphic-1024x500.png` ✅ |
| Phone screenshots | 2–8, min 320 px, 16:9 or 9:16 | `store/screenshots/` (5) ✅ |
| Privacy policy URL | public page | `store/privacy-policy.html` — **needs hosting** |

Screenshots were captured at 1080 × 2400 from a release build on a Pixel 8
emulator: deck list, a revealed verb card with its conjugation details, the
progress screen, search results, and settings. Regenerate with
`python3 tools/generate_icons.py` for the graphics; screenshots are captured
by hand from a running device.

The privacy policy still needs a public URL. The simplest route is GitHub
Pages on this repository: put `privacy-policy.html` in a `docs/` folder, enable
Pages for `main` → `/docs`, and use the resulting URL in the Play listing.

## Before you submit

- [x] Build with a real upload key (`android/key.properties` present).
- [x] Feature graphic and screenshots prepared.
- [x] Privacy policy written (`store/privacy-policy.md` / `.html`).
- [x] Deck provenance recorded in `tools/deck_sources.json`; verbatim textbook
      text excluded from the shipped content; CC BY-SA attribution shown in
      the app under Settings → Licences.
- [ ] **Host the privacy policy** and put the URL in the Play listing.
- [ ] **Decide on the five textbook-derived decks.** Their word selection
      follows "Menschen im Beruf: Bewerbungstraining". See `LICENSES.md`.
- [ ] Set the `versionCode`/`versionName` you want in `pubspec.yaml`.
- [ ] Install the `.aab` output on a **physical** device and study a full
      session, including audio, before promoting past internal testing.
