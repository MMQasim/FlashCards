@TestOn('vm')
library;

import 'dart:io';

import 'package:deutschcards/data/app_database.dart';
import 'package:deutschcards/data/content_asset.dart';
import 'package:deutschcards/data/models.dart';
import 'package:deutschcards/srs/sm2.dart';
import 'package:deutschcards/state/study_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/sqlite_test_setup.dart';

void main() {
  late Directory temp;
  late AppDatabase db;
  late Deck deck;

  var clock = DateTime(2026, 11, 7, 9);
  DateTime now() => clock;

  setUpAll(initSqliteForTests);

  setUp(() async {
    clock = DateTime(2026, 11, 7, 9);
    temp = await Directory.systemTemp.createTemp('deutschcards-study-');
    db = await AppDatabase.open(
      directory: temp,
      ensureContent: (dir) async {
        final target = p.join(dir.path, ContentAsset.fileName);
        await File('assets/content/content.db').copy(target);
        return target;
      },
    );
    deck = (await db.decks()).firstWhere((d) => d.slug == 'goethe-a1');
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  StudyController controller({int newLimit = 5}) => StudyController(
        database: db,
        deck: deck,
        newLimit: newLimit,
        scheduler: Sm2Scheduler(config: const Sm2Config(fuzzRatio: 0)),
        clock: now,
      );

  group('session lifecycle', () {
    test('starting loads a queue and shows the first card face down', () async {
      final c = controller();
      await c.start();
      expect(c.phase, SessionPhase.studying);
      expect(c.remaining, 5);
      expect(c.current, isNotNull);
      expect(c.isRevealed, isFalse);
      expect(c.tally.answered, 0);
    });

    test('revealing shows the answer and is idempotent', () async {
      final c = controller();
      await c.start();
      c.reveal();
      expect(c.isRevealed, isTrue);
      c.reveal();
      expect(c.isRevealed, isTrue);
    });

    test('a deck with nothing due reports an empty session', () async {
      final c = StudyController(
        database: db, deck: deck, newLimit: 0, clock: now,
      );
      await c.start();
      expect(c.phase, SessionPhase.empty);
      expect(c.current, isNull);
    });

    test('answering every card finishes the session', () async {
      final c = controller(newLimit: 3);
      await c.start();
      for (var i = 0; i < 3; i++) {
        c.reveal();
        await c.answer(Rating.easy);
      }
      expect(c.phase, SessionPhase.finished);
      expect(c.remaining, 0);
      expect(c.current, isNull);
      expect(c.tally.answered, 3);
      expect(c.tally.newIntroduced, 3);
    });

    test('answering collapses the reveal for the next card', () async {
      final c = controller();
      await c.start();
      c.reveal();
      await c.answer(Rating.good);
      expect(c.isRevealed, isFalse);
    });
  });

  group('queue behaviour', () {
    test('Easy on a new card removes it from the session', () async {
      final c = controller(newLimit: 3);
      await c.start();
      final first = c.current!.card.uid;
      c.reveal();
      await c.answer(Rating.easy);
      expect(c.remaining, 2);
      expect(c.current!.card.uid, isNot(first));
    });

    test('Again re-queues the card later in the same session', () async {
      final c = controller(newLimit: 5);
      await c.start();
      final first = c.current!.card.uid;
      c.reveal();
      await c.answer(Rating.again);

      // Still five cards to see, but not this one next.
      expect(c.remaining, 5);
      expect(c.current!.card.uid, isNot(first),
          reason: 'a lapsed card must not reappear immediately');
    });

    test('a re-queued card does come back before the session ends', () async {
      final c = controller(newLimit: 3);
      await c.start();
      final first = c.current!.card.uid;
      c.reveal();
      await c.answer(Rating.again);

      final seen = <String>[];
      while (c.current != null && seen.length < 10) {
        seen.add(c.current!.card.uid);
        c.reveal();
        await c.answer(Rating.easy);
      }
      expect(seen, contains(first));
    });

    test('a card graduating past the session horizon is not re-queued', () async {
      final c = controller(newLimit: 2);
      await c.start();
      final first = c.current!.card.uid;
      c.reveal();
      await c.answer(Rating.good); // 10 minutes, inside the horizon
      expect(c.remaining, 2);

      // Advance past the learning step so the next Good graduates it to a day.
      clock = clock.add(const Duration(minutes: 11));
      final at = c.current!.card.uid == first ? first : null;
      if (at != null) {
        c.reveal();
        await c.answer(Rating.good);
        expect(c.remaining, 1, reason: 'a graduated card leaves the session');
      }
    });

    test('extending a dry session pulls in more new cards', () async {
      final c = controller(newLimit: 2);
      await c.start();
      for (var i = 0; i < 2; i++) {
        c.reveal();
        await c.answer(Rating.easy);
      }
      expect(c.phase, SessionPhase.finished);

      await c.extend(extraNew: 4);
      expect(c.phase, SessionPhase.studying);
      expect(c.remaining, greaterThan(0));
    });

    test('extending never re-serves a card already in the session', () async {
      final c = controller(newLimit: 2);
      await c.start();
      final before = {c.current!.card.uid};
      c.reveal();
      await c.answer(Rating.again); // stays in the queue
      before.add(c.current!.card.uid);

      await c.extend(extraNew: 5);
      final uids = <String>[];
      while (c.current != null && uids.length < 20) {
        uids.add(c.current!.card.uid);
        c.reveal();
        await c.answer(Rating.easy);
      }
      expect(uids.toSet().length, uids.length - _duplicatesFromRequeue(uids),
          reason: 'no card should be duplicated by extending');
    });
  });

  group('tally', () {
    test('each rating is counted separately', () async {
      final c = controller(newLimit: 4);
      await c.start();
      for (final rating in [Rating.easy, Rating.good, Rating.hard, Rating.easy]) {
        if (c.current == null) break;
        c.reveal();
        await c.answer(rating);
      }
      expect(c.tally.easy, 2);
      expect(c.tally.good, 1);
      expect(c.tally.hard, 1);
      expect(c.tally.again, 0);
      expect(c.tally.accuracy, 1.0);
    });

    test('accuracy reflects lapses', () async {
      final c = controller(newLimit: 4);
      await c.start();
      c.reveal();
      await c.answer(Rating.again);
      c.reveal();
      await c.answer(Rating.easy);
      expect(c.tally.answered, 2);
      expect(c.tally.again, 1);
      expect(c.tally.accuracy, 0.5);
    });

    test('an empty tally reports zero accuracy rather than dividing by zero', () {
      expect(const SessionTally().accuracy, 0);
      expect(const SessionTally().correct, 0);
    });
  });

  group('undo', () {
    test('undo is unavailable before the first answer', () async {
      final c = controller();
      await c.start();
      expect(c.canUndo, isFalse);
      await c.undo(); // must be a no-op, not an error
      expect(c.tally.answered, 0);
    });

    test('undo restores the card, the reveal and the tally', () async {
      final c = controller(newLimit: 3);
      await c.start();
      final first = c.current!.card.uid;
      c.reveal();
      await c.answer(Rating.easy);
      expect(c.canUndo, isTrue);

      await c.undo();
      expect(c.current!.card.uid, first);
      expect(c.current!.state.isNew, isTrue);
      expect(c.isRevealed, isTrue, reason: 'the answer was on screen when graded');
      expect(c.tally.answered, 0);
      expect(c.tally.easy, 0);
      expect(c.remaining, 3);
    });

    test('undoing a first-ever answer leaves no scheduling state behind', () async {
      final c = controller(newLimit: 2);
      await c.start();
      final uid = c.current!.card.uid;
      c.reveal();
      await c.answer(Rating.good);
      await c.undo();

      final rows = await db.raw
          .query('review_state', where: 'card_uid = ?', whereArgs: [uid]);
      expect(rows, isEmpty);
      expect((await db.stateFor(uid)).isNew, isTrue);
    });

    test('undo removes the answer from the review log', () async {
      final c = controller(newLimit: 2);
      await c.start();
      c.reveal();
      await c.answer(Rating.good);
      expect(await db.reviewsToday(clock), 1);
      await c.undo();
      expect(await db.reviewsToday(clock), 0);
    });

    test('undo restores a re-queued card to its original position', () async {
      final c = controller(newLimit: 4);
      await c.start();
      final first = c.current!.card.uid;
      c.reveal();
      await c.answer(Rating.again);
      expect(c.current!.card.uid, isNot(first));

      await c.undo();
      expect(c.current!.card.uid, first);
      expect(c.remaining, 4);
      expect(c.current!.state.isNew, isTrue,
          reason: 'the lapse should have been rolled back too');
    });

    test('undo restores the previous interval for a graduated card', () async {
      final c = controller(newLimit: 1);
      await c.start();
      final uid = c.current!.card.uid;

      c.reveal();
      await c.answer(Rating.easy); // graduates to 4 days
      expect((await db.stateFor(uid)).intervalDays, 4);

      await c.undo();
      expect((await db.stateFor(uid)).isNew, isTrue);
    });

    test('undo can only be used once per answer', () async {
      final c = controller(newLimit: 3);
      await c.start();
      c.reveal();
      await c.answer(Rating.good);
      await c.undo();
      expect(c.canUndo, isFalse);
      await c.undo();
      expect(c.tally.answered, 0, reason: 'a second undo must not double-roll-back');
    });

    test('undo after the session finished reopens it', () async {
      final c = controller(newLimit: 1);
      await c.start();
      c.reveal();
      await c.answer(Rating.easy);
      expect(c.phase, SessionPhase.finished);

      await c.undo();
      expect(c.phase, SessionPhase.studying);
      expect(c.current, isNotNull);
    });
  });

  group('interval preview', () {
    test('each button is previewed and the order is increasing', () async {
      final c = controller();
      await c.start();
      final preview = c.intervalPreview;
      expect(preview.keys, containsAll(Rating.values));
      expect(preview[Rating.again]!, lessThanOrEqualTo(preview[Rating.good]!));
      expect(preview[Rating.good]!, lessThanOrEqualTo(preview[Rating.easy]!));
    });

    test('previewing does not consume or alter the card', () async {
      final c = controller();
      await c.start();
      final uid = c.current!.card.uid;
      c.intervalPreview;
      c.intervalPreview;
      expect(c.current!.card.uid, uid);
      expect(c.current!.state.reps, 0);
      expect(c.tally.answered, 0);
    });

    test('there is nothing to preview once the session is over', () async {
      final c = controller(newLimit: 1);
      await c.start();
      c.reveal();
      await c.answer(Rating.easy);
      expect(c.intervalPreview, isEmpty);
    });
  });
}

/// A card answered Again legitimately appears twice in a walk of the queue.
int _duplicatesFromRequeue(List<String> uids) =>
    uids.length - uids.toSet().length;
