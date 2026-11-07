/// Immutable view models over the bundled content database.
library;

import 'dart:convert';

import '../srs/sm2.dart';

/// A bundled deck of cards.
class Deck {
  const Deck({
    required this.id,
    required this.slug,
    required this.name,
    required this.cardCount,
    this.level,
    this.description,
    this.sortOrder = 0,
  });

  factory Deck.fromRow(Map<String, Object?> row) => Deck(
        id: row['id']! as int,
        slug: row['slug']! as String,
        name: row['name']! as String,
        cardCount: (row['card_count'] as int?) ?? 0,
        level: row['level'] as String?,
        description: row['description'] as String?,
        sortOrder: (row['sort_order'] as int?) ?? 0,
      );

  final int id;
  final String slug;
  final String name;
  final String? level;
  final String? description;
  final int cardCount;
  final int sortOrder;
}

/// One labelled detail row shown on the answer side (conjugations, plural,
/// usage notes - whatever the source notetype carried).
class CardDetail {
  const CardDetail({required this.label, required this.value});

  final String label;
  final String value;

  /// Multi-line values are conjugation tables and read better as a block.
  bool get isBlock => value.contains('\n') || value.length > 60;
}

/// A studiable card: one direction of one source note.
class Flashcard {
  const Flashcard({
    required this.uid,
    required this.deckId,
    required this.front,
    required this.back,
    required this.frontLang,
    required this.backLang,
    this.speakText,
    this.speakExample,
    this.exampleDe,
    this.exampleEn,
    this.details = const [],
    this.tags,
  });

  factory Flashcard.fromRow(Map<String, Object?> row) => Flashcard(
        uid: row['uid']! as String,
        deckId: row['deck_id']! as int,
        front: row['front']! as String,
        back: row['back']! as String,
        frontLang: (row['front_lang'] as String?) ?? 'de',
        backLang: (row['back_lang'] as String?) ?? 'en',
        speakText: _blankToNull(row['speak_text'] as String?),
        speakExample: _blankToNull(row['speak_example'] as String?),
        exampleDe: _blankToNull(row['example_de'] as String?),
        exampleEn: _blankToNull(row['example_en'] as String?),
        details: _parseDetails(row['extras'] as String?),
        tags: _blankToNull(row['tags'] as String?),
      );

  final String uid;
  final int deckId;
  final String front;
  final String back;

  /// `de` or `en` - which language the prompt is in.
  final String frontLang;
  final String backLang;

  /// German text to pronounce. Always German regardless of card direction, so
  /// the speaker button means the same thing on every card.
  final String? speakText;
  final String? speakExample;
  final String? exampleDe;
  final String? exampleEn;
  final List<CardDetail> details;
  final String? tags;

  bool get promptIsGerman => frontLang == 'de';

  /// What the speaker button reads out, preferring the term over the sentence.
  String? get primarySpeech => speakText ?? (promptIsGerman ? front : back);

  static String? _blankToNull(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;

  static List<CardDetail> _parseDetails(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, Object?>>()
          .map((e) => CardDetail(
                label: (e['label'] as String?) ?? '',
                value: (e['value'] as String?) ?? '',
              ))
          .where((d) => d.label.isNotEmpty && d.value.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      // A malformed extras blob should cost one card's detail sheet, not the
      // whole study session.
      return const [];
    }
  }
}

/// A card paired with its scheduling state, which is what the study screen
/// actually works with.
class StudyCard {
  const StudyCard({required this.card, required this.state});

  final Flashcard card;
  final ReviewState state;

  StudyCard withState(ReviewState next) => StudyCard(card: card, state: next);
}

/// Per-deck counts driving the deck list and the session planner.
class DeckProgress {
  const DeckProgress({
    required this.total,
    required this.newCards,
    required this.learning,
    required this.dueReviews,
    required this.known,
  });

  static const empty =
      DeckProgress(total: 0, newCards: 0, learning: 0, dueReviews: 0, known: 0);

  final int total;
  final int newCards;
  final int learning;
  final int dueReviews;

  /// Graduated cards with an interval of at least 21 days - the usual
  /// "mature card" threshold.
  final int known;

  int get studiedCards => total - newCards;
  int get dueNow => learning + dueReviews;
  double get knownRatio => total == 0 ? 0 : known / total;
  double get seenRatio => total == 0 ? 0 : studiedCards / total;
}

/// One answered card, for the stats screen.
class ReviewEvent {
  const ReviewEvent({
    required this.cardUid,
    required this.rating,
    required this.reviewedAt,
    required this.intervalDays,
  });

  final String cardUid;
  final Rating rating;
  final DateTime reviewedAt;
  final int intervalDays;
}

/// Aggregate counts for one calendar day.
class DailyActivity {
  const DailyActivity({required this.day, required this.reviews, required this.correct});

  final DateTime day;
  final int reviews;
  final int correct;

  double get accuracy => reviews == 0 ? 0 : correct / reviews;
}
