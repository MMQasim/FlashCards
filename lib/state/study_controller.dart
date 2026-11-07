/// Drives one study session.
///
/// Owns the queue, the reveal state and the running session tally. Scheduling
/// decisions are delegated to [Sm2Scheduler] and persistence to [AppDatabase];
/// this class only decides what the user sees next.
library;

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import '../srs/sm2.dart';

/// What happened to the last answered card, so the UI can offer an undo.
class _UndoEntry {
  const _UndoEntry({
    required this.card,
    required this.previousState,
    required this.rating,
    required this.queueIndex,
    required this.wasRequeued,
  });

  final Flashcard card;
  final ReviewState previousState;

  /// Recorded rather than re-derived from the graded state: several ratings can
  /// produce the same phase and step, so deriving it is ambiguous.
  final Rating rating;
  final int queueIndex;
  final bool wasRequeued;
}

/// Running totals for the session summary.
class SessionTally {
  const SessionTally({
    this.answered = 0,
    this.again = 0,
    this.hard = 0,
    this.good = 0,
    this.easy = 0,
    this.newIntroduced = 0,
  });

  final int answered;
  final int again;
  final int hard;
  final int good;
  final int easy;
  final int newIntroduced;

  int get correct => answered - again;
  double get accuracy => answered == 0 ? 0 : correct / answered;

  SessionTally plus(Rating rating, {required bool wasNew}) => SessionTally(
        answered: answered + 1,
        again: again + (rating == Rating.again ? 1 : 0),
        hard: hard + (rating == Rating.hard ? 1 : 0),
        good: good + (rating == Rating.good ? 1 : 0),
        easy: easy + (rating == Rating.easy ? 1 : 0),
        newIntroduced: newIntroduced + (wasNew ? 1 : 0),
      );

  SessionTally minus(Rating rating, {required bool wasNew}) => SessionTally(
        answered: answered - 1,
        again: again - (rating == Rating.again ? 1 : 0),
        hard: hard - (rating == Rating.hard ? 1 : 0),
        good: good - (rating == Rating.good ? 1 : 0),
        easy: easy - (rating == Rating.easy ? 1 : 0),
        newIntroduced: newIntroduced - (wasNew ? 1 : 0),
      );
}

enum SessionPhase { loading, studying, finished, empty, failed }

class StudyController extends ChangeNotifier {
  StudyController({
    required AppDatabase database,
    required this.deck,
    Sm2Scheduler? scheduler,
    DateTime Function()? clock,
    this.newLimit = 20,
    this.reviewLimit = 200,
    this.newOrder = NewCardOrder.authored,
  })  : _db = database,
        _scheduler = scheduler ?? Sm2Scheduler(),
        _now = clock ?? DateTime.now;

  /// A learning card comes back after this many other cards, so it is not
  /// re-shown while the answer is still on screen.
  static const _requeueGap = 3;

  final AppDatabase _db;
  final Deck deck;
  final Sm2Scheduler _scheduler;
  final DateTime Function() _now;
  final int newLimit;
  final int reviewLimit;
  final NewCardOrder newOrder;

  final List<StudyCard> _queue = [];
  int _index = 0;
  bool _revealed = false;
  SessionPhase _phase = SessionPhase.loading;
  String? _error;
  SessionTally _tally = const SessionTally();
  _UndoEntry? _undo;
  DateTime? _shownAt;

  SessionPhase get phase => _phase;
  String? get error => _error;
  SessionTally get tally => _tally;
  bool get isRevealed => _revealed;
  bool get canUndo => _undo != null;

  /// Cards still waiting in this session, including the current one.
  int get remaining => _queue.length - _index;
  StudyCard? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;

  /// What each answer button would schedule, for the button subtitles.
  Map<Rating, Duration> get intervalPreview {
    final card = current;
    if (card == null) return const {};
    return _scheduler.previewIntervals(card.state, _now());
  }

  Future<void> start() async {
    _phase = SessionPhase.loading;
    notifyListeners();
    try {
      final queue = await _db.buildQueue(
        deckId: deck.id,
        now: _now(),
        newLimit: newLimit,
        reviewLimit: reviewLimit,
        newOrder: newOrder,
      );
      _queue
        ..clear()
        ..addAll(queue);
      _index = 0;
      _revealed = false;
      _tally = const SessionTally();
      _undo = null;
      _phase = queue.isEmpty ? SessionPhase.empty : SessionPhase.studying;
      _shownAt = _now();
    } on Exception catch (error) {
      _phase = SessionPhase.failed;
      _error = '$error';
      debugPrint('StudyController: could not build queue: $error');
    }
    notifyListeners();
  }

  void reveal() {
    if (_revealed || current == null) return;
    _revealed = true;
    notifyListeners();
  }

  /// Applies [rating] to the current card, persists it and moves on.
  Future<void> answer(Rating rating) async {
    final card = current;
    if (card == null) return;

    final now = _now();
    final previousState = card.state;
    final next = _scheduler.grade(previousState, rating, now);
    final thinkingTime = _shownAt == null ? null : now.difference(_shownAt!);

    try {
      await _db.recordReview(state: next, rating: rating, thinkingTime: thinkingTime);
    } on Exception catch (error) {
      // Keep the session going but do not pretend the answer was saved.
      _error = 'Could not save that answer: $error';
      debugPrint('StudyController: recordReview failed: $error');
      notifyListeners();
      return;
    }

    _tally = _tally.plus(rating, wasNew: previousState.isNew);

    // A card still in learning comes back later in the same session, as long as
    // its delay fits inside a realistic sitting.
    final stillLearning =
        next.phase == CardPhase.learning || next.phase == CardPhase.relearning;
    final dueSoon = next.dueAt != null &&
        next.dueAt!.difference(now) <= const Duration(minutes: 20);
    final requeue = stillLearning && dueSoon;

    _undo = _UndoEntry(
      card: card.card,
      previousState: previousState,
      rating: rating,
      queueIndex: _index,
      wasRequeued: requeue,
    );

    _queue[_index] = card.withState(next);
    if (requeue) {
      _queue.removeAt(_index);
      final target = (_index + _requeueGap).clamp(_index, _queue.length);
      _queue.insert(target, card.withState(next));
    } else {
      _index++;
    }

    _revealed = false;
    _shownAt = _now();
    if (remaining <= 0) _phase = SessionPhase.finished;
    notifyListeners();
  }

  /// Reverts the last answer, restoring both the queue position and the
  /// persisted scheduling state.
  Future<void> undo() async {
    final entry = _undo;
    if (entry == null) return;
    _undo = null;

    try {
      await _db.undoLastReview(entry.card.uid, entry.previousState);
    } on Exception catch (error) {
      _error = 'Could not undo: $error';
      debugPrint('StudyController: undo failed: $error');
      notifyListeners();
      return;
    }

    final restored = StudyCard(card: entry.card, state: entry.previousState);
    if (entry.wasRequeued) {
      // The card was moved further down the queue; take it back out.
      final at = _queue.indexWhere((c) => c.card.uid == entry.card.uid);
      if (at >= 0) _queue.removeAt(at);
      _queue.insert(entry.queueIndex, restored);
    } else {
      _queue[entry.queueIndex] = restored;
    }
    _index = entry.queueIndex;

    _tally = _tally.minus(entry.rating, wasNew: entry.previousState.isNew);
    _revealed = true; // the user was looking at the answer when they graded it
    _phase = SessionPhase.studying;
    _shownAt = _now();
    notifyListeners();
  }

  /// Adds more new cards to a session that has run dry.
  Future<void> extend({int extraNew = 10}) async {
    final seen = _queue.map((c) => c.card.uid).toSet();
    try {
      final more = await _db.buildQueue(
        deckId: deck.id,
        now: _now(),
        newLimit: extraNew,
        reviewLimit: reviewLimit,
        newOrder: newOrder,
      );
      final fresh = more.where((c) => !seen.contains(c.card.uid)).toList();
      if (fresh.isEmpty) return;
      _queue.addAll(fresh);
      _phase = SessionPhase.studying;
      _shownAt = _now();
    } on Exception catch (error) {
      _error = '$error';
      debugPrint('StudyController: could not extend session: $error');
    }
    notifyListeners();
  }

  void dismissError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
