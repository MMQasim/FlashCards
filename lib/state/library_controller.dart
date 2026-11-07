/// State for the deck list and the statistics screen.
library;

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models.dart';

class LibraryController extends ChangeNotifier {
  LibraryController({required AppDatabase database, DateTime Function()? clock})
      : _db = database,
        _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  List<Deck> _decks = const [];
  Map<int, DeckProgress> _progress = const {};
  int _reviewsToday = 0;
  int _streak = 0;
  bool _loading = true;
  String? _error;

  List<Deck> get decks => _decks;
  bool get isLoading => _loading;
  String? get error => _error;
  int get reviewsToday => _reviewsToday;
  int get streak => _streak;

  DeckProgress progressFor(int deckId) => _progress[deckId] ?? DeckProgress.empty;

  /// Cards waiting across every deck, for the home header.
  int get totalDue =>
      _progress.values.fold(0, (sum, p) => sum + p.dueNow);
  int get totalCards => _progress.values.fold(0, (sum, p) => sum + p.total);

  /// Cards never answered, across every deck.
  int get totalNew => _progress.values.fold(0, (sum, p) => sum + p.newCards);
  int get totalKnown => _progress.values.fold(0, (sum, p) => sum + p.known);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final now = _now();
      final results = await Future.wait([
        _db.decks(),
        _db.allDeckProgress(now),
        _db.reviewsToday(now),
        _db.currentStreak(now),
      ]);
      _decks = results[0] as List<Deck>;
      _progress = results[1] as Map<int, DeckProgress>;
      _reviewsToday = results[2] as int;
      _streak = results[3] as int;
    } on Exception catch (error) {
      _error = 'Could not load your decks: $error';
      debugPrint('LibraryController: load failed: $error');
    }
    _loading = false;
    notifyListeners();
  }

  /// Refreshes counts without showing the full-screen loading state, for
  /// returning from a study session.
  Future<void> refresh() async {
    try {
      final now = _now();
      _progress = await _db.allDeckProgress(now);
      _reviewsToday = await _db.reviewsToday(now);
      _streak = await _db.currentStreak(now);
      notifyListeners();
    } on Exception catch (error) {
      debugPrint('LibraryController: refresh failed: $error');
    }
  }

  Future<List<DailyActivity>> activity({int days = 30}) =>
      _db.recentActivity(_now(), days: days);

  Future<List<int>> forecast({int days = 14}) =>
      _db.dueForecast(_now(), days: days);

  Future<void> resetDeck(int deckId) async {
    await _db.resetDeck(deckId);
    await refresh();
  }
}
