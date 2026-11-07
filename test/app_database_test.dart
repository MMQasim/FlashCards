@TestOn('vm')
library;

import 'dart:io';

import 'package:deutschcards/data/app_database.dart';
import 'package:deutschcards/data/content_asset.dart';
import 'package:deutschcards/srs/sm2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/sqlite_test_setup.dart';

/// Exercises the real bundled content database, so a mapping or query mistake
/// shows up here rather than on a device.
void main() {
  late Directory temp;
  late AppDatabase db;
  final now = DateTime(2026, 11, 7, 9);

  setUpAll(initSqliteForTests);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('deutschcards-test-');
    db = await AppDatabase.open(
      directory: temp,
      // The asset bundle is unavailable under `flutter test`, so the committed
      // content database is copied straight from the repository.
      ensureContent: (dir) async {
        final target = p.join(dir.path, ContentAsset.fileName);
        await File('assets/content/content.db').copy(target);
        return target;
      },
    );
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  group('bundled content', () {
    test('every deck is present and non-empty', () async {
      final decks = await db.decks();
      expect(decks, hasLength(11));
      for (final deck in decks) {
        expect(deck.cardCount, greaterThan(0), reason: '${deck.slug} is empty');
        expect(deck.name, isNotEmpty);
        expect(deck.slug, isNotEmpty);
      }
      expect(decks.map((d) => d.slug).toSet(), hasLength(11),
          reason: 'deck slugs must be unique');
    });

    test('decks come back in the authored order', () async {
      final decks = await db.decks();
      expect(decks.first.slug, 'goethe-a1');
      final orders = decks.map((d) => d.sortOrder).toList();
      expect(orders, orders.toList()..sort());
    });

    test('card bodies are clean plain text', () async {
      final rows = await db.raw.rawQuery(
        'SELECT front, back FROM content.card LIMIT 4000',
      );
      for (final row in rows) {
        final front = row['front']! as String;
        final back = row['back']! as String;
        expect(front, isNotEmpty);
        expect(back, isNotEmpty);
        expect(front, isNot(contains('[sound:')));
        expect(back, isNot(contains('[sound:')));
        expect(back, isNot(contains('&nbsp;')));
        expect(back, isNot(matches(RegExp('<(div|br|h1|table|td)'))));
      }
    });

    test('a known A1 word is reachable with its example sentence', () async {
      final results = await db.search('Apotheke');
      expect(results, isNotEmpty);
      final card = results.firstWhere((c) => c.front == 'die Apotheke, -n',
          orElse: () => results.first);
      expect(card.speakText, isNotNull);
      expect(card.primarySpeech, isNotNull);
    });

    test('verb cards carry their conjugation tables as details', () async {
      final results = await db.search('abbrechen');
      final verb = results.firstWhere((c) => c.front == 'abbrechen');
      final labels = verb.details.map((d) => d.label).toList();
      expect(labels, contains('Present'));
      expect(labels, contains('Auxiliary'));
      final present = verb.details.firstWhere((d) => d.label == 'Present');
      expect(present.value, contains('ich breche ab'));
      expect(present.isBlock, isTrue, reason: 'conjugations render as a block');
    });

    test('search folds umlauts in both the query and the content', () async {
      final folded = await db.search('grosse');
      final direct = await db.search('große');
      expect(folded, isNotEmpty);
      expect(direct, isNotEmpty);
      expect(await db.search('uber'), isNotEmpty);
    });

    test('search can be limited to one deck', () async {
      final decks = await db.decks();
      final itWork = decks.firstWhere((d) => d.slug == 'core-it-work');
      final results = await db.search('e', deckId: itWork.id, limit: 50);
      expect(results, isNotEmpty);
      for (final card in results) {
        expect(card.deckId, itWork.id);
      }
    });

    test('search results carry the deck they came from', () async {
      final results = await db.search('arbeiten', limit: 20);
      expect(results, isNotEmpty);
      expect(results.every((c) => c.deckName != null && c.deckName!.isNotEmpty),
          isTrue, reason: 'the same word appears in several decks');
    });

    test('an article is not repeated when the noun already carries it', () async {
      final doubled = await db.raw.rawQuery(
        "SELECT COUNT(*) AS n FROM content.card "
        "WHERE lower(front) GLOB 'd[ei][rs] d[ei][rs] *' "
        "   OR lower(back)  GLOB 'd[ei][rs] d[ei][rs] *'",
      );
      expect(doubled.first['n'], 0);
    });

    test('no card side is a bare placeholder', () async {
      final rows = await db.raw.rawQuery(
        "SELECT COUNT(*) AS n FROM content.card "
        "WHERE trim(front) IN ('…','...','-','—') OR trim(back) IN ('…','...','-','—')",
      );
      expect(rows.first['n'], 0);
    });

    test('no shipped detail comes from the source textbook', () async {
      final rows = await db.raw.rawQuery(
        "SELECT COUNT(*) AS n FROM content.note "
        // GLOB is case-sensitive and the quotes pin this to the JSON label,
        // so ordinary words such as "Homepages" do not trip it.
        r"""WHERE extras GLOB '*"BookContext"*' OR extras GLOB '*"Pages"*'""",
      );
      expect(rows.first['n'], 0,
          reason: 'Pages and BookContext are excluded for rights reasons');
    });

    test('detail labels are human readable, not raw field names', () async {
      final rows = await db.raw.rawQuery(
        "SELECT extras FROM content.note WHERE extras IS NOT NULL LIMIT 2000",
      );
      for (final row in rows) {
        final raw = row['extras']! as String;
        expect(raw, isNot(contains('"CoreMeaning"')));
        expect(raw, isNot(contains('"ParticipleII"')));
        expect(raw, isNot(contains('"Part_of_Speech"')));
      }
    });

    test('verb family cards ask for the family, not a wall of text', () async {
      final deck = (await db.decks()).firstWhere((d) => d.slug == 'it-verbs-families');
      final cards = await db.browseDeck(deck.id, limit: 500);
      expect(cards, isNotEmpty);

      // The source deck stored a whole rendered page as the answer; the worst
      // card was 39,620 characters. Nothing should come close now.
      final longest = cards.map((c) => c.card.back.length).reduce((a, b) => a > b ? a : b);
      expect(longest, lessThan(400),
          reason: 'answers must stay gradable at a glance');

      final families = cards.where((c) => c.card.front.endsWith('word family'));
      expect(families, isNotEmpty);
      for (final family in families) {
        // Every member is listed as "verb — meaning" on its own line.
        expect(family.card.back, contains('—'));
        expect(family.card.backLang, 'de');
        expect(family.card.speakText, isNotEmpty);
      }
    });

    test('individual IT verbs keep their conjugations as details', () async {
      final results = await db.search('vertippen', limit: 10);
      final verb = results.firstWhere((c) => c.front == 'vertippen');
      expect(verb.back, 'to mistype');

      final labels = verb.details.map((d) => d.label).toList();
      expect(labels, contains('Verb family'));
      expect(labels, contains('Separable'));
      expect(labels, contains('Präsens'));
      expect(labels, contains('Perfekt'));

      final present = verb.details.firstWhere((d) => d.label == 'Präsens');
      expect(present.value, contains('ich vertippe mich'));
    });

    test('a one-verb family says so instead of looking incomplete', () async {
      final deck = (await db.decks()).firstWhere((d) => d.slug == 'it-verbs-families');
      final cards = await db.browseDeck(deck.id, limit: 600);
      final families =
          cards.where((c) => c.card.front.endsWith('word family')).toList();
      expect(families.length, 99, reason: 'every family in the source is kept');

      final singles = families.where((c) => !c.card.back.contains('\n')).toList();
      expect(singles, isNotEmpty, reason: 'loan verbs such as deployen stand alone');
      for (final single in singles) {
        final labels = single.card.details.map((d) => d.label);
        expect(labels, contains('Prefixed forms'),
            reason: '${single.card.front} must explain why it has one member');
      }

      // The multi-member cards still list one verb per line.
      for (final family in families.where((c) => c.card.back.contains('\n'))) {
        expect(family.card.back.split('\n').length, greaterThan(1));
      }
    });

    test('search returns nothing for a blank query instead of everything', () async {
      expect(await db.search('   '), isEmpty);
      expect(await db.search(''), isEmpty);
    });

    test('both study directions exist for a reversible deck', () async {
      final results = await db.search('bekommen', limit: 200);
      expect(results.any((c) => c.promptIsGerman), isTrue);
      expect(results.any((c) => !c.promptIsGerman), isTrue);
    });
  });

  group('queue building', () {
    Future<int> deckId(String slug) async =>
        (await db.decks()).firstWhere((d) => d.slug == slug).id;

    test('a fresh deck yields only new cards, capped at the limit', () async {
      final id = await deckId('goethe-a1');
      final queue = await db.buildQueue(deckId: id, now: now, newLimit: 12);
      expect(queue, hasLength(12));
      expect(queue.every((c) => c.state.isNew), isTrue);
      expect(queue.map((c) => c.card.uid).toSet(), hasLength(12),
          reason: 'no card should appear twice in one queue');
    });

    test('the queue only contains cards from the requested deck', () async {
      final id = await deckId('job-verbs');
      final queue = await db.buildQueue(deckId: id, now: now, newLimit: 30);
      expect(queue, isNotEmpty);
      for (final item in queue) {
        expect(item.card.deckId, id);
      }
    });

    test('a new limit of zero introduces nothing', () async {
      final id = await deckId('goethe-a1');
      expect(await db.buildQueue(deckId: id, now: now, newLimit: 0), isEmpty);
    });

    test('answered cards drop out of the new-card pool', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler();
      final first = await db.buildQueue(deckId: id, now: now, newLimit: 5);

      for (final item in first) {
        final graded = scheduler.grade(item.state, Rating.easy, now);
        await db.recordReview(state: graded, rating: Rating.easy);
      }

      final second = await db.buildQueue(deckId: id, now: now, newLimit: 5);
      final firstUids = first.map((c) => c.card.uid).toSet();
      expect(second.map((c) => c.card.uid).toSet().intersection(firstUids), isEmpty);
    });

    test('learning cards that are due are served before new cards', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler();
      final seed = await db.buildQueue(deckId: id, now: now, newLimit: 3);

      // Answering Again leaves these in learning, due a minute later.
      for (final item in seed) {
        final graded = scheduler.grade(item.state, Rating.again, now);
        await db.recordReview(state: graded, rating: Rating.again);
      }

      final later = now.add(const Duration(minutes: 5));
      final queue = await db.buildQueue(deckId: id, now: later, newLimit: 5);
      expect(queue.length, greaterThan(3));
      expect(
        queue.take(3).every((c) => c.state.phase == CardPhase.learning),
        isTrue,
        reason: 'due learning cards must come first',
      );
    });

    test('a learning card not yet due is withheld', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler();
      final seed = await db.buildQueue(deckId: id, now: now, newLimit: 1);
      final graded = scheduler.grade(seed.single.state, Rating.good, now);
      await db.recordReview(state: graded, rating: Rating.good);

      // Due in 10 minutes; at +1 minute it must not reappear.
      final queue =
          await db.buildQueue(deckId: id, now: now.add(const Duration(minutes: 1)), newLimit: 0);
      expect(queue, isEmpty);
    });

    test('a graduated card returns on the day it falls due, not before', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler(config: const Sm2Config(fuzzRatio: 0));
      final seed = await db.buildQueue(deckId: id, now: now, newLimit: 1);
      final graded = scheduler.grade(seed.single.state, Rating.easy, now); // 4 days
      await db.recordReview(state: graded, rating: Rating.easy);

      final tooEarly =
          await db.buildQueue(deckId: id, now: now.add(const Duration(days: 2)), newLimit: 0);
      expect(tooEarly, isEmpty);

      final onTime =
          await db.buildQueue(deckId: id, now: now.add(const Duration(days: 4)), newLimit: 0);
      expect(onTime, hasLength(1));
      expect(onTime.single.state.phase, CardPhase.review);
    });

    test('random order draws a different set than authored order', () async {
      final id = await deckId('core-general');
      final authored = await db.buildQueue(deckId: id, now: now, newLimit: 20);
      final random = await db.buildQueue(
          deckId: id, now: now, newLimit: 20, newOrder: NewCardOrder.random);
      expect(random, hasLength(20));
      final overlap = authored.map((c) => c.card.uid).toSet()
          .intersection(random.map((c) => c.card.uid).toSet());
      expect(overlap.length, lessThan(20),
          reason: 'random ordering should not reproduce the authored head');
    });
  });

  group('progress and stats', () {
    Future<int> deckId(String slug) async =>
        (await db.decks()).firstWhere((d) => d.slug == slug).id;

    test('an untouched deck is all new', () async {
      final id = await deckId('goethe-a1');
      final progress = await db.deckProgress(id, now);
      expect(progress.total, progress.newCards);
      expect(progress.dueNow, 0);
      expect(progress.known, 0);
      expect(progress.knownRatio, 0);
    });

    test('deck progress follows a review through to maturity', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler(config: const Sm2Config(fuzzRatio: 0));
      final seed = await db.buildQueue(deckId: id, now: now, newLimit: 1);

      var state = seed.single.state;
      var clock = now;
      // Answer Easy repeatedly until the interval crosses the mature threshold.
      for (var i = 0; i < 4; i++) {
        state = scheduler.grade(state, Rating.easy, clock);
        await db.recordReview(state: state, rating: Rating.easy);
        clock = state.dueAt!;
      }

      final progress = await db.deckProgress(id, clock);
      expect(state.intervalDays, greaterThanOrEqualTo(AppDatabase.matureIntervalDays));
      expect(progress.known, 1);
      expect(progress.newCards, progress.total - 1);
      expect(progress.seenRatio, greaterThan(0));
    });

    test('per-deck progress is reported for every deck in one query', () async {
      final all = await db.allDeckProgress(now);
      final decks = await db.decks();
      expect(all, hasLength(decks.length));
      var sum = 0;
      for (final deck in decks) {
        expect(all[deck.id]!.total, deck.cardCount,
            reason: '${deck.slug} count disagrees with the deck row');
        sum += all[deck.id]!.total;
      }
      expect(sum, 11549);
    });

    test('reviews today counts only reviews from today', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler();
      final seed = await db.buildQueue(deckId: id, now: now, newLimit: 3);
      for (final item in seed) {
        await db.recordReview(
            state: scheduler.grade(item.state, Rating.good, now), rating: Rating.good);
      }
      expect(await db.reviewsToday(now), 3);
      expect(await db.reviewsToday(now.add(const Duration(days: 1))), 0);
    });

    test('the streak counts consecutive days and tolerates a quiet today', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler();
      final cards = await db.buildQueue(deckId: id, now: now, newLimit: 3);

      for (var i = 0; i < 3; i++) {
        final day = now.subtract(Duration(days: i));
        final state = scheduler.grade(cards[i].state, Rating.good, day);
        await db.recordReview(state: state, rating: Rating.good);
      }

      expect(await db.currentStreak(now), 3);
      expect(await db.currentStreak(now.add(const Duration(days: 1))), 3,
          reason: 'a day that has not finished yet must not break the streak');
      expect(await db.currentStreak(now.add(const Duration(days: 2))), 0);
    });

    test('activity history is padded to the requested window', () async {
      final history = await db.recentActivity(now, days: 7);
      expect(history, hasLength(7));
      expect(history.first.day.isBefore(history.last.day), isTrue);
      expect(history.every((d) => d.reviews == 0), isTrue);
    });

    test('activity history separates correct answers from lapses', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler();
      final cards = await db.buildQueue(deckId: id, now: now, newLimit: 2);
      await db.recordReview(
          state: scheduler.grade(cards[0].state, Rating.good, now), rating: Rating.good);
      await db.recordReview(
          state: scheduler.grade(cards[1].state, Rating.again, now), rating: Rating.again);

      final today = (await db.recentActivity(now, days: 1)).single;
      expect(today.reviews, 2);
      expect(today.correct, 1);
      expect(today.accuracy, 0.5);
    });

    test('the forecast buckets upcoming reviews by day', () async {
      final id = await deckId('goethe-a1');
      final scheduler = Sm2Scheduler(config: const Sm2Config(fuzzRatio: 0));
      final cards = await db.buildQueue(deckId: id, now: now, newLimit: 2);
      for (final card in cards) {
        await db.recordReview(
            state: scheduler.grade(card.state, Rating.easy, now), rating: Rating.easy);
      }
      final forecast = await db.dueForecast(now, days: 7);
      expect(forecast, hasLength(7));
      expect(forecast[4], 2, reason: 'Easy on a new card schedules it 4 days out');
    });
  });

  group('persistence', () {
    Future<int> deckId(String slug) async =>
        (await db.decks()).firstWhere((d) => d.slug == slug).id;

    test('scheduling state round-trips through the database', () async {
      final id = await deckId('goethe-a1');
      final card = (await db.buildQueue(deckId: id, now: now, newLimit: 1)).single;
      final scheduler = Sm2Scheduler(config: const Sm2Config(fuzzRatio: 0));
      final graded = scheduler.grade(card.state, Rating.hard, now);
      await db.recordReview(state: graded, rating: Rating.hard);

      final loaded = await db.stateFor(card.card.uid);
      expect(loaded.phase, graded.phase);
      expect(loaded.ease, closeTo(graded.ease, 1e-9));
      expect(loaded.intervalDays, graded.intervalDays);
      expect(loaded.reps, graded.reps);
      expect(loaded.step, graded.step);
      expect(loaded.dueAt, graded.dueAt);
    });

    test('an unseen card reports a fresh state rather than failing', () async {
      final state = await db.stateFor('no-such-card');
      expect(state.isNew, isTrue);
      expect(state.reps, 0);
    });

    test('re-reviewing a card replaces its state and appends to the log', () async {
      final id = await deckId('goethe-a1');
      final card = (await db.buildQueue(deckId: id, now: now, newLimit: 1)).single;
      final scheduler = Sm2Scheduler();

      var state = scheduler.grade(card.state, Rating.good, now);
      await db.recordReview(state: state, rating: Rating.good);
      state = scheduler.grade(state, Rating.good, now);
      await db.recordReview(state: state, rating: Rating.good);

      final rows = await db.raw.rawQuery(
          'SELECT COUNT(*) AS n FROM review_state WHERE card_uid = ?', [card.card.uid]);
      expect(rows.first['n'], 1, reason: 'one state row per card');
      expect(await db.reviewsToday(now), 2, reason: 'every answer is logged');
    });

    test('resetting a deck clears its progress and leaves others alone', () async {
      final goethe = await deckId('goethe-a1');
      final verbs = await deckId('job-verbs');
      final scheduler = Sm2Scheduler();

      for (final id in [goethe, verbs]) {
        for (final card in await db.buildQueue(deckId: id, now: now, newLimit: 2)) {
          await db.recordReview(
              state: scheduler.grade(card.state, Rating.good, now), rating: Rating.good);
        }
      }

      await db.resetDeck(goethe);

      final goetheProgress = await db.deckProgress(goethe, now);
      final verbProgress = await db.deckProgress(verbs, now);
      expect(goetheProgress.newCards, goetheProgress.total);
      expect(verbProgress.newCards, verbProgress.total - 2);
    });

    test('deck preferences default sensibly and persist once saved', () async {
      final defaults = await db.deckPref('goethe-a1');
      expect(defaults.newPerDay, 20);
      expect(defaults.maxReviewsPerDay, 200);
      expect(defaults.isPinned, isFalse);

      await db.saveDeckPref(defaults.copyWith(newPerDay: 7, isPinned: true));
      final saved = await db.deckPref('goethe-a1');
      expect(saved.newPerDay, 7);
      expect(saved.isPinned, isTrue);
      expect(saved.maxReviewsPerDay, 200, reason: 'untouched fields are preserved');
    });

    test('settings round-trip and missing keys return null', () async {
      expect(await db.settingValue('theme'), isNull);
      await db.setSetting('theme', 'dark');
      expect(await db.settingValue('theme'), 'dark');
      await db.setSetting('theme', 'light');
      expect(await db.settingValue('theme'), 'light');
    });

    test('progress survives reopening the database', () async {
      final id = await deckId('goethe-a1');
      final card = (await db.buildQueue(deckId: id, now: now, newLimit: 1)).single;
      await db.recordReview(
          state: Sm2Scheduler().grade(card.state, Rating.good, now), rating: Rating.good);
      await db.close();

      db = await AppDatabase.open(
        directory: temp,
        ensureContent: (dir) async => p.join(dir.path, ContentAsset.fileName),
      );
      expect((await db.stateFor(card.card.uid)).reps, 1);
    });
  });

  group('browsing', () {
    test('a deck can be paged through with its scheduling state attached', () async {
      final id = (await db.decks()).firstWhere((d) => d.slug == 'core-general').id;
      final firstPage = await db.browseDeck(id, limit: 10);
      expect(firstPage, hasLength(10));
      expect(firstPage.every((c) => c.card.deckId == id), isTrue);
      expect(firstPage.every((c) => c.state.isNew), isTrue);

      final secondPage = await db.browseDeck(id, limit: 10, offset: 10);
      expect(
        firstPage.map((c) => c.card.uid).toSet()
            .intersection(secondPage.map((c) => c.card.uid).toSet()),
        isEmpty,
      );
    });
  });
}
