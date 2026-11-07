/// The app's single database connection.
///
/// `review.db` is writable and holds everything the user generates: scheduling
/// state, the review log and per-deck preferences. The bundled content database
/// is ATTACHed as `content`, which lets SQLite do the joins between a card and
/// its scheduling state instead of shuttling thousands of uids through Dart.
/// Nothing ever writes to the attached database.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../srs/sm2.dart';
import 'content_asset.dart';
import 'models.dart';

/// How cards are ordered when a study session introduces new material.
enum NewCardOrder { authored, random }

class AppDatabase {
  AppDatabase._(this._db);

  static const reviewFileName = 'review.db';
  static const _reviewSchemaVersion = 1;

  /// Cards with an interval of at least this many days count as "known".
  static const matureIntervalDays = 21;

  final Database _db;

  Database get raw => _db;

  /// Opens the writable review database and attaches the bundled content.
  ///
  /// [directory] is where both files live; [databaseFactory] and
  /// [openDatabaseFn] are injectable so tests can run against sqflite's FFI
  /// implementation on the host.
  static Future<AppDatabase> open({
    required Directory directory,
    Future<String> Function(Directory) ensureContent = ContentAsset.ensureExtracted,
  }) async {
    final contentPath = await ensureContent(directory);
    final reviewPath = p.join(directory.path, reviewFileName);

    final db = await openDatabase(
      reviewPath,
      version: _reviewSchemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (final statement in _createStatements) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, from, to) async {
        // Only version 1 exists so far. Future migrations append here; the
        // review database is never recreated, because it is the one thing that
        // cannot be rebuilt from the app bundle.
        debugPrint('AppDatabase: migrating review schema $from -> $to');
      },
    );

    await db.execute('ATTACH DATABASE ? AS content', [contentPath]);
    return AppDatabase._(db);
  }

  static const _createStatements = <String>[
    '''
    CREATE TABLE review_state (
      card_uid         TEXT    PRIMARY KEY,
      phase            TEXT    NOT NULL DEFAULT 'new',
      ease             REAL    NOT NULL DEFAULT 2.5,
      interval_days    INTEGER NOT NULL DEFAULT 0,
      step             INTEGER NOT NULL DEFAULT 0,
      reps             INTEGER NOT NULL DEFAULT 0,
      lapses           INTEGER NOT NULL DEFAULT 0,
      due_at           INTEGER,
      last_reviewed_at INTEGER
    )
    ''',
    'CREATE INDEX review_due_idx ON review_state(due_at)',
    'CREATE INDEX review_phase_idx ON review_state(phase)',
    '''
    CREATE TABLE review_log (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      card_uid      TEXT    NOT NULL,
      rating        INTEGER NOT NULL,
      reviewed_at   INTEGER NOT NULL,
      interval_days INTEGER NOT NULL DEFAULT 0,
      ease          REAL,
      elapsed_ms    INTEGER
    )
    ''',
    'CREATE INDEX review_log_time_idx ON review_log(reviewed_at)',
    '''
    CREATE TABLE deck_pref (
      deck_slug           TEXT    PRIMARY KEY,
      new_per_day         INTEGER NOT NULL DEFAULT 20,
      max_reviews_per_day INTEGER NOT NULL DEFAULT 200,
      is_pinned           INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE setting (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
  ];

  Future<void> close() async {
    await _db.execute('DETACH DATABASE content');
    await _db.close();
  }

  // --- content reads -------------------------------------------------------

  Future<List<Deck>> decks() async {
    final rows = await _db.rawQuery(
      'SELECT id, slug, name, level, description, card_count, sort_order '
      'FROM content.deck ORDER BY sort_order, name',
    );
    return rows.map(Deck.fromRow).toList(growable: false);
  }

  static const _cardColumns = '''
    c.uid, c.deck_id, c.front, c.back, c.front_lang, c.back_lang,
    n.speak_text, n.speak_example, n.example_de, n.example_en, n.extras, n.tags
  ''';

  Future<Flashcard?> cardByUid(String uid) async {
    final rows = await _db.rawQuery(
      'SELECT $_cardColumns FROM content.card c '
      'JOIN content.note n ON n.id = c.note_id WHERE c.uid = ? LIMIT 1',
      [uid],
    );
    return rows.isEmpty ? null : Flashcard.fromRow(rows.first);
  }

  /// Diacritic-insensitive substring search over both sides of every card.
  Future<List<Flashcard>> search(String query, {int? deckId, int limit = 80}) async {
    final needle = foldForSearch(query.trim());
    if (needle.isEmpty) return const [];
    final rows = await _db.rawQuery(
      'SELECT $_cardColumns FROM content.card c '
      'JOIN content.note n ON n.id = c.note_id '
      'WHERE c.search LIKE ?${deckId != null ? ' AND c.deck_id = ?' : ''} '
      'ORDER BY length(c.front), c.sort_order LIMIT ?',
      ['%$needle%', if (deckId != null) deckId, limit],
    );
    return rows.map(Flashcard.fromRow).toList(growable: false);
  }

  /// Every card of a deck with its scheduling state, for the browser screen.
  Future<List<StudyCard>> browseDeck(int deckId, {int limit = 500, int offset = 0}) async {
    final rows = await _db.rawQuery(
      'SELECT $_cardColumns, $_stateColumns FROM content.card c '
      'JOIN content.note n ON n.id = c.note_id '
      'LEFT JOIN review_state s ON s.card_uid = c.uid '
      'WHERE c.deck_id = ? ORDER BY c.sort_order, c.id LIMIT ? OFFSET ?',
      [deckId, limit, offset],
    );
    return rows.map(_studyCardFromRow).toList(growable: false);
  }

  // --- scheduling state ----------------------------------------------------

  static const _stateColumns = '''
    s.phase, s.ease, s.interval_days, s.step, s.reps, s.lapses,
    s.due_at, s.last_reviewed_at
  ''';

  static ReviewState _stateFromRow(String uid, Map<String, Object?> row) {
    if (row['phase'] == null) return ReviewState.initial(uid);
    return ReviewState(
      cardUid: uid,
      phase: CardPhase.fromId(row['phase']! as String),
      ease: (row['ease'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (row['interval_days'] as int?) ?? 0,
      step: (row['step'] as int?) ?? 0,
      reps: (row['reps'] as int?) ?? 0,
      lapses: (row['lapses'] as int?) ?? 0,
      dueAt: _toDate(row['due_at']),
      lastReviewedAt: _toDate(row['last_reviewed_at']),
    );
  }

  static StudyCard _studyCardFromRow(Map<String, Object?> row) {
    final card = Flashcard.fromRow(row);
    return StudyCard(card: card, state: _stateFromRow(card.uid, row));
  }

  static DateTime? _toDate(Object? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis as int);

  Future<ReviewState> stateFor(String uid) async {
    final rows = await _db.query('review_state',
        where: 'card_uid = ?', whereArgs: [uid], limit: 1);
    return rows.isEmpty ? ReviewState.initial(uid) : _stateFromRow(uid, rows.first);
  }

  /// Persists scheduling state and appends to the review log in one transaction,
  /// so a crash can never record a review without its state change.
  Future<void> recordReview({
    required ReviewState state,
    required Rating rating,
    Duration? thinkingTime,
  }) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'review_state',
        {
          'card_uid': state.cardUid,
          'phase': state.phase.id,
          'ease': state.ease,
          'interval_days': state.intervalDays,
          'step': state.step,
          'reps': state.reps,
          'lapses': state.lapses,
          'due_at': state.dueAt?.millisecondsSinceEpoch,
          'last_reviewed_at': state.lastReviewedAt?.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('review_log', {
        'card_uid': state.cardUid,
        'rating': rating.value,
        'reviewed_at':
            (state.lastReviewedAt ?? DateTime.now()).millisecondsSinceEpoch,
        'interval_days': state.intervalDays,
        'ease': state.ease,
        'elapsed_ms': thinkingTime?.inMilliseconds,
      });
    });
  }

  /// Clears all progress for one deck, leaving other decks untouched.
  Future<void> resetDeck(int deckId) async {
    await _db.rawDelete(
      'DELETE FROM review_state WHERE card_uid IN '
      '(SELECT uid FROM content.card WHERE deck_id = ?)',
      [deckId],
    );
    await _db.rawDelete(
      'DELETE FROM review_log WHERE card_uid IN '
      '(SELECT uid FROM content.card WHERE deck_id = ?)',
      [deckId],
    );
  }

  // --- queue building -----------------------------------------------------

  /// Builds a study queue for one deck.
  ///
  /// Order of priority: cards already in learning or relearning that are due,
  /// then due reviews (oldest first), then new cards up to [newLimit]. Returning
  /// learning cards first keeps a session from piling up half-learned material.
  Future<List<StudyCard>> buildQueue({
    required int deckId,
    required DateTime now,
    int newLimit = 20,
    int reviewLimit = 200,
    NewCardOrder newOrder = NewCardOrder.authored,
    int? seed,
  }) async {
    final nowMs = now.millisecondsSinceEpoch;
    final endOfDayMs = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;

    // Learning and relearning cards due now, soonest first.
    final learning = await _db.rawQuery(
      'SELECT $_cardColumns, $_stateColumns FROM review_state s '
      'JOIN content.card c ON c.uid = s.card_uid '
      'JOIN content.note n ON n.id = c.note_id '
      "WHERE c.deck_id = ? AND s.phase IN ('learning','relearning') "
      'AND s.due_at <= ? ORDER BY s.due_at LIMIT ?',
      [deckId, nowMs, reviewLimit],
    );

    // Graduated cards whose due date has arrived, most overdue first.
    final reviews = await _db.rawQuery(
      'SELECT $_cardColumns, $_stateColumns FROM review_state s '
      'JOIN content.card c ON c.uid = s.card_uid '
      'JOIN content.note n ON n.id = c.note_id '
      "WHERE c.deck_id = ? AND s.phase = 'review' AND s.due_at < ? "
      'ORDER BY s.due_at LIMIT ?',
      [deckId, endOfDayMs, reviewLimit],
    );

    final newCards = newLimit <= 0
        ? const <Map<String, Object?>>[]
        : await _db.rawQuery(
            'SELECT $_cardColumns, $_stateColumns FROM content.card c '
            'JOIN content.note n ON n.id = c.note_id '
            'LEFT JOIN review_state s ON s.card_uid = c.uid '
            'WHERE c.deck_id = ? AND s.card_uid IS NULL '
            'ORDER BY ${newOrder == NewCardOrder.random ? 'RANDOM()' : 'c.sort_order, c.id'} '
            'LIMIT ?',
            [deckId, newLimit],
          );

    return [
      ...learning.map(_studyCardFromRow),
      ...reviews.map(_studyCardFromRow),
      ...newCards.map(_studyCardFromRow),
    ];
  }

  // --- progress and stats -------------------------------------------------

  /// Counts for one deck in a single pass over its cards.
  Future<DeckProgress> deckProgress(int deckId, DateTime now) async {
    final endOfDayMs = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    final nowMs = now.millisecondsSinceEpoch;

    final rows = await _db.rawQuery(
      '''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN s.card_uid IS NULL THEN 1 ELSE 0 END) AS new_cards,
        SUM(CASE WHEN s.phase IN ('learning','relearning')
                  AND s.due_at <= ? THEN 1 ELSE 0 END) AS learning,
        SUM(CASE WHEN s.phase = 'review' AND s.due_at < ? THEN 1 ELSE 0 END) AS due_reviews,
        SUM(CASE WHEN s.phase = 'review' AND s.interval_days >= ? THEN 1 ELSE 0 END) AS known
      FROM content.card c
      LEFT JOIN review_state s ON s.card_uid = c.uid
      WHERE c.deck_id = ?
      ''',
      [nowMs, endOfDayMs, matureIntervalDays, deckId],
    );

    final row = rows.first;
    int count(String key) => (row[key] as int?) ?? 0;
    return DeckProgress(
      total: count('total'),
      newCards: count('new_cards'),
      learning: count('learning'),
      dueReviews: count('due_reviews'),
      known: count('known'),
    );
  }

  /// Deck progress for every deck at once, so the deck list needs one query.
  Future<Map<int, DeckProgress>> allDeckProgress(DateTime now) async {
    final endOfDayMs = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    final nowMs = now.millisecondsSinceEpoch;

    final rows = await _db.rawQuery(
      '''
      SELECT c.deck_id AS deck_id,
        COUNT(*) AS total,
        SUM(CASE WHEN s.card_uid IS NULL THEN 1 ELSE 0 END) AS new_cards,
        SUM(CASE WHEN s.phase IN ('learning','relearning')
                  AND s.due_at <= ? THEN 1 ELSE 0 END) AS learning,
        SUM(CASE WHEN s.phase = 'review' AND s.due_at < ? THEN 1 ELSE 0 END) AS due_reviews,
        SUM(CASE WHEN s.phase = 'review' AND s.interval_days >= ? THEN 1 ELSE 0 END) AS known
      FROM content.card c
      LEFT JOIN review_state s ON s.card_uid = c.uid
      GROUP BY c.deck_id
      ''',
      [nowMs, endOfDayMs, matureIntervalDays],
    );

    return {
      for (final row in rows)
        row['deck_id']! as int: DeckProgress(
          total: (row['total'] as int?) ?? 0,
          newCards: (row['new_cards'] as int?) ?? 0,
          learning: (row['learning'] as int?) ?? 0,
          dueReviews: (row['due_reviews'] as int?) ?? 0,
          known: (row['known'] as int?) ?? 0,
        ),
    };
  }

  /// How many cards were answered today, used for the daily goal ring.
  Future<int> reviewsToday(DateTime now) async {
    final startMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM review_log WHERE reviewed_at >= ?',
      [startMs],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Daily review counts for the last [days] days, oldest first.
  Future<List<DailyActivity>> recentActivity(DateTime now, {int days = 30}) async {
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final rows = await _db.rawQuery(
      'SELECT reviewed_at, rating FROM review_log WHERE reviewed_at >= ?',
      [start.millisecondsSinceEpoch],
    );

    final byDay = <DateTime, List<int>>{};
    for (final row in rows) {
      final at = DateTime.fromMillisecondsSinceEpoch(row['reviewed_at']! as int);
      final day = DateTime(at.year, at.month, at.day);
      (byDay[day] ??= []).add(row['rating']! as int);
    }

    return [
      for (var i = 0; i < days; i++)
        () {
          final day = start.add(Duration(days: i));
          final ratings = byDay[day] ?? const [];
          return DailyActivity(
            day: day,
            reviews: ratings.length,
            correct: ratings.where((r) => r > Rating.again.value).length,
          );
        }(),
    ];
  }

  /// Consecutive days up to and including today with at least one review.
  Future<int> currentStreak(DateTime now) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT reviewed_at FROM review_log ORDER BY reviewed_at DESC LIMIT 20000',
    );
    final days = <DateTime>{};
    for (final row in rows) {
      final at = DateTime.fromMillisecondsSinceEpoch(row['reviewed_at']! as int);
      days.add(DateTime(at.year, at.month, at.day));
    }
    if (days.isEmpty) return 0;

    var cursor = DateTime(now.year, now.month, now.day);
    // A streak survives a day that has not finished yet: if nothing was
    // reviewed today, start counting from yesterday.
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// How many cards fall due on each of the next [days] days.
  Future<List<int>> dueForecast(DateTime now, {int days = 14}) async {
    final today = DateTime(now.year, now.month, now.day);
    final rows = await _db.rawQuery(
      "SELECT due_at FROM review_state WHERE phase = 'review' AND due_at IS NOT NULL",
    );
    final forecast = List.filled(days, 0);
    for (final row in rows) {
      final due = DateTime.fromMillisecondsSinceEpoch(row['due_at']! as int);
      final offset = DateTime(due.year, due.month, due.day).difference(today).inDays;
      if (offset < 0) {
        forecast[0]++; // already overdue, show against today
      } else if (offset < days) {
        forecast[offset]++;
      }
    }
    return forecast;
  }

  // --- preferences --------------------------------------------------------

  Future<DeckPref> deckPref(String slug) async {
    final rows = await _db.query('deck_pref',
        where: 'deck_slug = ?', whereArgs: [slug], limit: 1);
    if (rows.isEmpty) return DeckPref(deckSlug: slug);
    final row = rows.first;
    return DeckPref(
      deckSlug: slug,
      newPerDay: (row['new_per_day'] as int?) ?? 20,
      maxReviewsPerDay: (row['max_reviews_per_day'] as int?) ?? 200,
      isPinned: ((row['is_pinned'] as int?) ?? 0) == 1,
    );
  }

  Future<void> saveDeckPref(DeckPref pref) async {
    await _db.insert(
      'deck_pref',
      {
        'deck_slug': pref.deckSlug,
        'new_per_day': pref.newPerDay,
        'max_reviews_per_day': pref.maxReviewsPerDay,
        'is_pinned': pref.isPinned ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> settingValue(String key) async {
    final rows =
        await _db.query('setting', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert('setting', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// Per-deck study limits.
class DeckPref {
  const DeckPref({
    required this.deckSlug,
    this.newPerDay = 20,
    this.maxReviewsPerDay = 200,
    this.isPinned = false,
  });

  final String deckSlug;
  final int newPerDay;
  final int maxReviewsPerDay;
  final bool isPinned;

  DeckPref copyWith({int? newPerDay, int? maxReviewsPerDay, bool? isPinned}) =>
      DeckPref(
        deckSlug: deckSlug,
        newPerDay: newPerDay ?? this.newPerDay,
        maxReviewsPerDay: maxReviewsPerDay ?? this.maxReviewsPerDay,
        isPinned: isPinned ?? this.isPinned,
      );
}

extension ReviewUndo on AppDatabase {
  /// Reverts the most recent answer for one card.
  ///
  /// Restores the scheduling state the card had beforehand and drops its newest
  /// log row, so an accidental tap does not permanently skew the statistics. A
  /// card answered for the first time goes back to having no state at all.
  Future<void> undoLastReview(String cardUid, ReviewState previous) async {
    await raw.transaction((txn) async {
      if (previous.isNew && previous.reps == 0) {
        await txn.delete('review_state', where: 'card_uid = ?', whereArgs: [cardUid]);
      } else {
        await txn.update(
          'review_state',
          {
            'phase': previous.phase.id,
            'ease': previous.ease,
            'interval_days': previous.intervalDays,
            'step': previous.step,
            'reps': previous.reps,
            'lapses': previous.lapses,
            'due_at': previous.dueAt?.millisecondsSinceEpoch,
            'last_reviewed_at': previous.lastReviewedAt?.millisecondsSinceEpoch,
          },
          where: 'card_uid = ?',
          whereArgs: [cardUid],
        );
      }
      await txn.rawDelete(
        'DELETE FROM review_log WHERE id = '
        '(SELECT id FROM review_log WHERE card_uid = ? ORDER BY id DESC LIMIT 1)',
        [cardUid],
      );
    });
  }
}
