/// SM-2 spaced repetition, as a pure function of (state, rating, now).
///
/// Deliberately free of any I/O or Flutter dependency so the whole scheduler is
/// unit-testable. [ReviewDatabase] persists what this returns; nothing here
/// reads or writes.
library;

import 'dart:math';

/// How well the card was recalled. Values are persisted in `review_log`, so
/// they must stay stable.
enum Rating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const Rating(this.value);
  final int value;

  static Rating fromValue(int value) =>
      Rating.values.firstWhere((r) => r.value == value, orElse: () => Rating.good);
}

/// Which part of the lifecycle a card is in. Persisted as text.
enum CardPhase {
  /// Never answered.
  isNew('new'),

  /// Being introduced, stepping through [Sm2Config.learningStepsMinutes].
  learning('learning'),

  /// Graduated; intervals measured in days.
  review('review'),

  /// Was in [review] and lapsed; stepping through
  /// [Sm2Config.relearningStepsMinutes] before returning to [review].
  relearning('relearning');

  const CardPhase(this.id);
  final String id;

  static CardPhase fromId(String id) =>
      CardPhase.values.firstWhere((p) => p.id == id, orElse: () => CardPhase.isNew);
}

/// Tunable scheduler parameters.
class Sm2Config {
  const Sm2Config({
    this.learningStepsMinutes = const [1, 10],
    this.relearningStepsMinutes = const [10],
    this.graduatingIntervalDays = 1,
    this.easyIntervalDays = 4,
    this.startingEase = 2.5,
    this.minimumEase = 1.3,
    this.easyBonus = 1.3,
    this.hardIntervalFactor = 1.2,
    this.lapseIntervalFactor = 0.0,
    this.maximumIntervalDays = 365 * 5,
    this.fuzzRatio = 0.05,
  });

  final List<int> learningStepsMinutes;
  final List<int> relearningStepsMinutes;
  final int graduatingIntervalDays;
  final int easyIntervalDays;
  final double startingEase;
  final double minimumEase;
  final double easyBonus;
  final double hardIntervalFactor;

  /// Fraction of the old interval kept after a lapse. 0 restarts from scratch.
  final double lapseIntervalFactor;
  final int maximumIntervalDays;

  /// Random spread applied to intervals of 2+ days so cards introduced together
  /// do not stay clumped on the same future day forever.
  final double fuzzRatio;

  static const Sm2Config standard = Sm2Config();
}

/// Everything the scheduler needs to know about one card's history.
class ReviewState {
  const ReviewState({
    required this.cardUid,
    this.phase = CardPhase.isNew,
    this.ease = 2.5,
    this.intervalDays = 0,
    this.step = 0,
    this.reps = 0,
    this.lapses = 0,
    this.dueAt,
    this.lastReviewedAt,
  });

  factory ReviewState.initial(String cardUid, {Sm2Config config = Sm2Config.standard}) =>
      ReviewState(cardUid: cardUid, ease: config.startingEase);

  final String cardUid;
  final CardPhase phase;
  final double ease;

  /// Current scheduling interval in days. 0 while learning.
  final int intervalDays;

  /// Index into the learning or relearning step list.
  final int step;
  final int reps;
  final int lapses;
  final DateTime? dueAt;
  final DateTime? lastReviewedAt;

  bool get isNew => phase == CardPhase.isNew;
  bool get isGraduated => phase == CardPhase.review;

  bool isDue(DateTime now) => dueAt == null || !dueAt!.isAfter(now);

  ReviewState copyWith({
    CardPhase? phase,
    double? ease,
    int? intervalDays,
    int? step,
    int? reps,
    int? lapses,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
  }) {
    return ReviewState(
      cardUid: cardUid,
      phase: phase ?? this.phase,
      ease: ease ?? this.ease,
      intervalDays: intervalDays ?? this.intervalDays,
      step: step ?? this.step,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}

/// The scheduler. Construct once and reuse; [random] is injectable so tests can
/// make interval fuzzing deterministic.
class Sm2Scheduler {
  Sm2Scheduler({this.config = Sm2Config.standard, Random? random})
      : _random = random ?? Random();

  final Sm2Config config;
  final Random _random;

  /// Applies [rating] to [state] and returns the next state.
  ///
  /// [now] is passed in rather than read from the clock so that review sessions
  /// and tests both get a single consistent timestamp.
  ReviewState grade(ReviewState state, Rating rating, DateTime now) {
    final next = switch (state.phase) {
      CardPhase.isNew || CardPhase.learning => _gradeLearning(state, rating, now),
      CardPhase.review => _gradeReview(state, rating, now),
      CardPhase.relearning => _gradeRelearning(state, rating, now),
    };
    return next.copyWith(reps: state.reps + 1, lastReviewedAt: now);
  }

  ReviewState _gradeLearning(ReviewState state, Rating rating, DateTime now) {
    final steps = config.learningStepsMinutes;

    switch (rating) {
      case Rating.again:
        return state.copyWith(
          phase: CardPhase.learning,
          step: 0,
          intervalDays: 0,
          dueAt: now.add(Duration(minutes: steps.first)),
        );

      case Rating.hard:
        // Repeat the current step rather than advancing; a new card that was
        // hard is not ready to move on.
        final minutes = steps[min(state.step, steps.length - 1)];
        return state.copyWith(
          phase: CardPhase.learning,
          intervalDays: 0,
          dueAt: now.add(Duration(minutes: minutes)),
        );

      case Rating.good:
        final nextStep = state.isNew ? 1 : state.step + 1;
        if (nextStep >= steps.length) {
          return _graduate(state, now, config.graduatingIntervalDays);
        }
        return state.copyWith(
          phase: CardPhase.learning,
          step: nextStep,
          intervalDays: 0,
          dueAt: now.add(Duration(minutes: steps[nextStep])),
        );

      case Rating.easy:
        // Skip the remaining learning steps entirely.
        return _graduate(state, now, config.easyIntervalDays);
    }
  }

  ReviewState _graduate(ReviewState state, DateTime now, int intervalDays) {
    final interval = _clampInterval(intervalDays);
    return state.copyWith(
      phase: CardPhase.review,
      step: 0,
      intervalDays: interval,
      dueAt: _dueInDays(now, interval),
    );
  }

  ReviewState _gradeReview(ReviewState state, Rating rating, DateTime now) {
    final current = max(1, state.intervalDays);

    if (rating == Rating.again) {
      final relearnMinutes = config.relearningStepsMinutes.first;
      return state.copyWith(
        phase: CardPhase.relearning,
        step: 0,
        lapses: state.lapses + 1,
        ease: _adjustEase(state.ease, -0.20),
        intervalDays: _clampInterval((current * config.lapseIntervalFactor).round()),
        dueAt: now.add(Duration(minutes: relearnMinutes)),
      );
    }

    final (double easeDelta, int interval) = switch (rating) {
      Rating.hard => (
          -0.15,
          max(current + 1, (current * config.hardIntervalFactor).round()),
        ),
      Rating.good => (0.0, max(current + 1, (current * state.ease).round())),
      Rating.easy => (
          0.15,
          max(current + 1, (current * state.ease * config.easyBonus).round()),
        ),
      Rating.again => (0.0, current), // handled above
    };

    final fuzzed = _clampInterval(_fuzz(interval));
    return state.copyWith(
      phase: CardPhase.review,
      step: 0,
      ease: _adjustEase(state.ease, easeDelta),
      intervalDays: fuzzed,
      dueAt: _dueInDays(now, fuzzed),
    );
  }

  ReviewState _gradeRelearning(ReviewState state, Rating rating, DateTime now) {
    final steps = config.relearningStepsMinutes;

    switch (rating) {
      case Rating.again:
        return state.copyWith(
          step: 0,
          dueAt: now.add(Duration(minutes: steps.first)),
        );

      case Rating.hard:
        final minutes = steps[min(state.step, steps.length - 1)];
        return state.copyWith(dueAt: now.add(Duration(minutes: minutes)));

      case Rating.good:
      case Rating.easy:
        final nextStep = state.step + 1;
        if (rating == Rating.good && nextStep < steps.length) {
          return state.copyWith(
            step: nextStep,
            dueAt: now.add(Duration(minutes: steps[nextStep])),
          );
        }
        // Back to review. A lapsed card resumes at a short interval rather than
        // its pre-lapse one, but keeps the ease penalty already applied.
        final resume = _clampInterval(max(1, state.intervalDays));
        return state.copyWith(
          phase: CardPhase.review,
          step: 0,
          intervalDays: resume,
          dueAt: _dueInDays(now, resume),
        );
    }
  }

  double _adjustEase(double ease, double delta) =>
      max(config.minimumEase, double.parse((ease + delta).toStringAsFixed(4)));

  int _clampInterval(int days) => days.clamp(1, config.maximumIntervalDays);

  /// Spreads intervals of 2+ days by up to [Sm2Config.fuzzRatio].
  int _fuzz(int days) {
    if (days < 2 || config.fuzzRatio <= 0) return days;
    final spread = max(1, (days * config.fuzzRatio).round());
    return days + _random.nextInt(spread * 2 + 1) - spread;
  }

  /// Due dates land at the start of the target day so that "due today" does not
  /// depend on the time of day a card was answered.
  DateTime _dueInDays(DateTime now, int days) {
    final target = DateTime(now.year, now.month, now.day).add(Duration(days: days));
    return target;
  }

  /// What each button will schedule, for the answer-button subtitles.
  ///
  /// Day-based results report the scheduled interval itself rather than the
  /// wall-clock gap. Due dates snap to midnight, so a card answered in the
  /// afternoon and scheduled four days out is only three days and some hours
  /// away, and reporting that as "3d" misstates the interval the user just
  /// chose. Sub-day results keep the real delay, which is what "10m" means.
  Map<Rating, Duration> previewIntervals(ReviewState state, DateTime now) {
    return {
      for (final rating in Rating.values) rating: _previewFor(state, rating, now),
    };
  }

  Duration _previewFor(ReviewState state, Rating rating, DateTime now) {
    final next = grade(state, rating, now);
    if (next.phase == CardPhase.review && next.intervalDays > 0) {
      return Duration(days: next.intervalDays);
    }
    final due = next.dueAt;
    return due == null ? Duration.zero : due.difference(now);
  }
}
