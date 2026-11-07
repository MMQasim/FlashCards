# Releasing DeutschCards to Google Play

A runbook, in order. Phases 0–3 can be done in an afternoon. Phase 4 has a
**mandatory 14-day wait** if you have a new personal developer account, so
start it as early as you can and do the remaining paperwork while it runs.

Everything the app needs is already built and signed. What is left is account
setup, hosting one URL, and Play Console paperwork.

---

## Phase 0 — Developer account

Skip if you already have one.

1. Go to <https://play.google.com/console/signup>.
2. Choose **Personal** or **Organisation**. This choice matters more than it
   looks: see the warning in Phase 4.
3. Pay the **one-time US$25 registration fee**.
4. Complete identity verification. Google asks for a government ID and a
   credit card **in your legal name**; the fee is not refunded if the details
   are judged invalid. Allow up to a few days for processing.

---

## Phase 1 — Publish the privacy policy

Google requires a privacy policy at a live public URL for **every** app,
including ones that collect nothing. `docs/index.html` is ready for GitHub
Pages.

```bash
cd /home/ekko/HomeGround/work/FlashCards
git push --force-with-lease origin main
```

Then on GitHub: **Settings → Pages → Source: Deploy from a branch →
`main` / `/docs` → Save.**

Wait a minute, then confirm the page loads:

    https://MMQasim.github.io/FlashCards/

Keep that URL. Phase 2 needs it.

> If the repository is private, GitHub Pages needs a paid plan. Either make it
> public (check `LICENSES.md` first — the deck content question) or host the
> policy somewhere else: a GitHub Gist, Netlify Drop, or any static host. The
> file is self-contained, so any of them works.

---

## Phase 2 — Create the app and fill in App content

In Play Console: **Create app**.

| Field | Value |
|---|---|
| App name | `DeutschCards` |
| Default language | English (United States) |
| App or game | App |
| Free or paid | Free |

Then work through **App content** in the left sidebar. Every item must be
answered before you can promote past internal testing.

- **Privacy policy** — the URL from Phase 1.
- **App access** — "All functionality is available without special access".
  There is no login.
- **Ads** — No, this app contains no ads.
- **Content ratings** — fill in the questionnaire. Educational app, no user
  content, no ads, no purchases. Expect Everyone / PEGI 3.
- **Target audience** — 13+ is the simplest honest answer. Choosing under-13
  pulls you into the Families policy and extra review.
- **Data safety** — **No** to collecting or sharing any user data. Say the
  app has no internet permission. Mention Android Auto Backup if the form asks
  about device transfer; `store/privacy-policy.md` already discloses it.
- **Government apps** — No.
- **Financial features** — None.
- **Health** — No.

Draft answers and listing copy: `store/listing.md`.
Release notes for every track: `store/release-notes.md`.

---

## Phase 3 — Store listing and first upload

### Store listing assets

All of these already exist in `store/`:

| Field | File / source |
|---|---|
| App icon (512×512) | `store/icon-512.png` |
| Feature graphic (1024×500) | `store/feature-graphic-1024x500.png` |
| Phone screenshots (2–8) | `store/screenshots/*.png` |
| Short description | `store/listing.md` |
| Full description | `store/listing.md` |
| Category | Education |

### Build the bundle

```bash
cd /home/ekko/HomeGround/work/FlashCards
flutter test          # expect: all tests passed
flutter analyze       # expect: no issues
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Confirm it is signed with your upload key and **not** the debug key:

```bash
~/HomeGround/JAVA/jdk-17_linux-x64_bin/jdk-17.0.8/bin/jarsigner \
  -verify -verbose:summary build/app/outputs/bundle/release/app-release.aab \
  | grep -E "Signed by|jar verified"
```

Expect `CN=Muhammad Qasim`. If you see `CN=Android Debug`, `android/key.properties`
is missing — see Phase 6.

### Upload to internal testing

**Testing → Internal testing → Create new release.**

1. Opt in to **Play App Signing** when prompted. Google then holds the app
   signing key and your `.jks` becomes the *upload* key. Accept this: it means
   a lost upload key can be reset instead of ending the app.
2. Upload the `.aab`.
3. Release notes: see `store/release-notes.md`.
4. Add yourself as a tester under **Testers**, then **Save → Review release →
   Start rollout**.
5. Install from the opt-in link on a **real Android phone**.

### What to check on real hardware

This is the only part never tested on anything but an emulator.

- [ ] First launch shows "Setting up your decks", then the deck list within a
      few seconds.
- [ ] The speaker button actually speaks German. **Most likely failure point** —
      TTS voice availability varies by manufacturer. If it is silent, check
      Settings → Pronunciation in the app; it reports whether a German voice
      was found.
- [ ] Study a full session: reveal, rate, undo, finish.
- [ ] Force-close and reopen — progress is still there.
- [ ] Search finds `über` when you type `uber`.

---

## Phase 4 — Closed testing ⚠️ start this early

> **If your developer account is a personal account created after
> 13 November 2023**, Google requires a closed test with **at least 12 testers
> opted in continuously for 14 days** before you can even apply for production
> access. Organisation accounts and older personal accounts are exempt.
>
> The 14 days are consecutive and the testers must still be opted in when you
> apply. A tester who leaves and rejoins restarts their own count. Meeting the
> threshold makes you *eligible* to apply — it does not guarantee approval.

So: **create the closed track and get 12 people enrolled as early as possible.**
The clock does not start until they are opted in.

1. **Testing → Closed testing → Create track.**
2. Create an email list with **12 or more** testers. Real people with real
   Google accounts; they must each accept the opt-in link.
3. Promote your internal build to the closed track.
4. Confirm in the dashboard that 12 testers show as opted in.
5. Wait 14 days. Collect feedback and ship fixes to the same track — updating
   the build does not reset the clock, but testers leaving does.

---

## Phase 5 — Production

1. **Apply for production access** once the 14 days are complete (new personal
   accounts only). Google asks what you learned from testing — answer
   specifically, not with boilerplate.
2. **Production → Create new release.**
3. Bump the version in `pubspec.yaml` before every upload:

   ```yaml
   version: 1.0.1+2    # versionName+versionCode
   ```

   Play rejects a bundle whose `versionCode` it has already seen. The number
   must increase; it can never be reused, even after a deleted release.
4. Rebuild, upload, submit for review.
5. First review commonly takes a few days and can take longer.

---

## Phase 6 — Keep these safe

Losing either of these means you can never update the app again:

| What | Where |
|---|---|
| Upload keystore | `~/deutschcards-upload.jks` |
| Its passwords | `android/key.properties` (gitignored, mode 600) |

Back both up somewhere off this machine. They are deliberately **not** in the
repository.

If you opted in to Play App Signing in Phase 3, a lost *upload* key can be
reset by Google support. Without it, a lost key is terminal.

---

## Still an open decision

Five decks (`job-nouns`, `job-verbs`, `job-adjectives`, `beruf-b2-verbs`,
`beruf-it-verbs` — 5,862 cards) follow the vocabulary of *Menschen im Beruf:
Bewerbungstraining* (Hueber). Verbatim book text and page references are
excluded from the shipped content, and the CC BY-SA attribution the Goethe A1
deck requires is shown in-app under Settings → Licences.

What remains is a judgement call about whether a vocabulary selection that
tracks a specific textbook is acceptable to publish commercially. See
`LICENSES.md`. To ship without them, delete those five entries from
`tools/deck_sources.json`, run `python3 tools/build_content.py`, and update the
card counts in the tests and docs.

---

## Quick command reference

```bash
# Full verification before any upload
flutter test && flutter analyze

# The Play artifact
flutter build appbundle --release

# Sideload to a connected phone instead
flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Rebuild deck content after editing tools/deck_sources.json
python3 tools/build_content.py && flutter test

# Rebuild icons, feature graphic and store images
python3 tools/generate_icons.py

# Regenerate the hosted privacy policy after editing the Markdown
python3 tools/md2html.py store/privacy-policy.md docs/index.html
```
