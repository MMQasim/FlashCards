import 'dart:math';

import 'package:deutschcards/srs/sm2.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed seed keeps interval fuzzing deterministic.
Sm2Scheduler scheduler({Sm2Config? config}) =>
    Sm2Scheduler(config: config ?? Sm2Config.standard, random: Random(42));

/// Fuzz-free scheduler for exact interval assertions.
Sm2Scheduler exactScheduler() =>
    Sm2Scheduler(config: const Sm2Config(fuzzRatio: 0), random: Random(1));

final now = DateTime(2026, 11, 7, 9, 0);

ReviewState newCard() => ReviewState.initial('card-1');

/// Walks a new card through the learning steps into the review phase.
ReviewState graduated(Sm2Scheduler s, {int intervalDays = 10, double ease = 2.5}) {
  return ReviewState(
    cardUid: 'card-1',
    phase: CardPhase.review,
    ease: ease,
    intervalDays: intervalDays,
    dueAt: now,
  );
}

void main() {
  group('new and learning cards', () {
    test('a new card starts at the configured ease and is immediately due', () {
      final card = newCard();
      expect(card.phase, CardPhase.isNew);
      expect(card.ease, 2.5);
      expect(card.intervalDays, 0);
      expect(card.isDue(now), isTrue, reason: 'cards with no due date are new and available');
    });

    test('Good on a new card advances to the second learning step', () {
      final next = scheduler().grade(newCard(), Rating.good, now);
      expect(next.phase, CardPhase.learning);
      expect(next.step, 1);
      expect(next.dueAt, now.add(const Duration(minutes: 10)));
      expect(next.reps, 1);
    });

    test('Good on the last learning step graduates to one day', () {
      final s = exactScheduler();
      final afterFirst = s.grade(newCard(), Rating.good, now);
      final next = s.grade(afterFirst, Rating.good, now);
      expect(next.phase, CardPhase.review);
      expect(next.intervalDays, 1);
      expect(next.step, 0);
    });

    test('Easy on a new card skips the remaining steps', () {
      final next = exactScheduler().grade(newCard(), Rating.easy, now);
      expect(next.phase, CardPhase.review);
      expect(next.intervalDays, 4);
    });

    test('Again resets a learning card to the first step', () {
      final s = scheduler();
      final advanced = s.grade(newCard(), Rating.good, now);
      final reset = s.grade(advanced, Rating.again, now);
      expect(reset.phase, CardPhase.learning);
      expect(reset.step, 0);
      expect(reset.dueAt, now.add(const Duration(minutes: 1)));
    });

    test('Hard repeats the current learning step without advancing', () {
      final s = scheduler();
      final advanced = s.grade(newCard(), Rating.good, now); // step 1
      final hard = s.grade(advanced, Rating.hard, now);
      expect(hard.step, 1, reason: 'Hard should not move the card forward');
      expect(hard.dueAt, now.add(const Duration(minutes: 10)));
    });

    test('learning cards never carry a day-based interval', () {
      final s = scheduler();
      var card = newCard();
      for (final rating in [Rating.hard, Rating.again, Rating.hard]) {
        card = s.grade(card, rating, now);
        expect(card.intervalDays, 0);
      }
    });
  });

  group('review cards', () {
    test('Good multiplies the interval by the ease factor', () {
      final next = exactScheduler()
          .grade(graduated(exactScheduler(), intervalDays: 10, ease: 2.5), Rating.good, now);
      expect(next.intervalDays, 25);
      expect(next.ease, 2.5, reason: 'Good leaves ease unchanged');
    });

    test('Hard grows the interval slowly and lowers ease', () {
      final next = exactScheduler()
          .grade(graduated(exactScheduler(), intervalDays: 10), Rating.hard, now);
      expect(next.intervalDays, 12);
      expect(next.ease, closeTo(2.35, 1e-9));
    });

    test('Easy applies the easy bonus and raises ease', () {
      final next = exactScheduler()
          .grade(graduated(exactScheduler(), intervalDays: 10), Rating.easy, now);
      expect(next.intervalDays, 33); // 10 * 2.5 * 1.3
      expect(next.ease, closeTo(2.65, 1e-9));
    });

    test('the interval always advances by at least one day', () {
      final s = exactScheduler();
      final lowEase = graduated(s, intervalDays: 1, ease: 1.3);
      expect(s.grade(lowEase, Rating.good, now).intervalDays, greaterThan(1));
    });

    test('Again sends the card to relearning, penalises ease and counts a lapse', () {
      final next = scheduler().grade(graduated(scheduler()), Rating.again, now);
      expect(next.phase, CardPhase.relearning);
      expect(next.lapses, 1);
      expect(next.ease, closeTo(2.30, 1e-9));
      expect(next.dueAt, now.add(const Duration(minutes: 10)));
    });

    test('ease never falls below the configured floor', () {
      final s = exactScheduler();
      var card = graduated(s, ease: 1.4);
      for (var i = 0; i < 10; i++) {
        card = s.grade(card, Rating.again, now);
        card = card.copyWith(phase: CardPhase.review);
      }
      expect(card.ease, greaterThanOrEqualTo(1.3));
    });

    test('intervals are capped at the configured maximum', () {
      const config = Sm2Config(fuzzRatio: 0, maximumIntervalDays: 100);
      final s = Sm2Scheduler(config: config, random: Random(1));
      final huge = ReviewState(
        cardUid: 'c',
        phase: CardPhase.review,
        ease: 2.5,
        intervalDays: 90,
        dueAt: now,
      );
      expect(s.grade(huge, Rating.easy, now).intervalDays, 100);
    });

    test('fuzzing keeps intervals close to the unfuzzed value', () {
      final fuzzed = scheduler().grade(graduated(scheduler(), intervalDays: 100), Rating.good, now);
      expect(fuzzed.intervalDays, closeTo(250, 15));
    });
  });

  group('relearning cards', () {
    ReviewState relearning(Sm2Scheduler s) =>
        s.grade(graduated(s, intervalDays: 20, ease: 2.5), Rating.again, now);

    test('Good returns the card to the review phase', () {
      final s = exactScheduler();
      final next = s.grade(relearning(s), Rating.good, now);
      expect(next.phase, CardPhase.review);
      expect(next.intervalDays, greaterThanOrEqualTo(1));
    });

    test('Again keeps the card in relearning', () {
      final s = scheduler();
      final next = s.grade(relearning(s), Rating.again, now);
      expect(next.phase, CardPhase.relearning);
      expect(next.step, 0);
    });

    test('the ease penalty from the lapse is retained on return to review', () {
      final s = exactScheduler();
      final next = s.grade(relearning(s), Rating.good, now);
      expect(next.ease, closeTo(2.30, 1e-9));
    });

    test('multiple relearning steps are stepped through in order', () {
      const config = Sm2Config(relearningStepsMinutes: [5, 20], fuzzRatio: 0);
      final s = Sm2Scheduler(config: config, random: Random(1));
      final lapsed = s.grade(graduated(s, intervalDays: 20), Rating.again, now);
      expect(lapsed.dueAt, now.add(const Duration(minutes: 5)));

      final second = s.grade(lapsed, Rating.good, now);
      expect(second.phase, CardPhase.relearning);
      expect(second.dueAt, now.add(const Duration(minutes: 20)));

      final back = s.grade(second, Rating.good, now);
      expect(back.phase, CardPhase.review);
    });
  });

  group('bookkeeping and due dates', () {
    test('every grading increments the repetition count', () {
      final s = scheduler();
      var card = newCard();
      for (var i = 1; i <= 5; i++) {
        card = s.grade(card, Rating.good, now);
        expect(card.reps, i);
      }
    });

    test('day-based due dates land at midnight so "due today" is time independent', () {
      final late = DateTime(2026, 11, 7, 23, 30);
      final next = exactScheduler().grade(newCard(), Rating.easy, late);
      expect(next.dueAt, DateTime(2026, 11, 11));
    });

    test('a card due in the future is not due now', () {
      final next = exactScheduler().grade(newCard(), Rating.easy, now);
      expect(next.isDue(now), isFalse);
      expect(next.isDue(now.add(const Duration(days: 5))), isTrue);
    });

    test('previewIntervals offers one duration per button and orders them', () {
      final s = exactScheduler();
      final preview = s.previewIntervals(graduated(s, intervalDays: 10), now);
      expect(preview.keys, containsAll(Rating.values));
      expect(preview[Rating.again]!, lessThan(preview[Rating.hard]!));
      expect(preview[Rating.hard]!, lessThan(preview[Rating.good]!));
      expect(preview[Rating.good]!, lessThan(preview[Rating.easy]!));
    });

    test('previewIntervals does not mutate the card it previews', () {
      final s = exactScheduler();
      final card = graduated(s, intervalDays: 10);
      s.previewIntervals(card, now);
      expect(card.reps, 0);
      expect(card.intervalDays, 10);
    });
  });

  group('enum persistence', () {
    test('rating values round-trip through their stored integer', () {
      for (final rating in Rating.values) {
        expect(Rating.fromValue(rating.value), rating);
      }
    });

    test('phase ids round-trip through their stored string', () {
      for (final phase in CardPhase.values) {
        expect(CardPhase.fromId(phase.id), phase);
      }
    });

    test('unknown stored values fall back instead of throwing', () {
      expect(Rating.fromValue(99), Rating.good);
      expect(CardPhase.fromId('bogus'), CardPhase.isNew);
    });
  });
}
