/// Theming for DeutschCards.
///
/// Card faces carry most of the screen, so typography is tuned for one large
/// word rather than paragraphs, and the rating buttons get fixed semantic
/// colours that survive both light and dark schemes.
library;

import 'package:flutter/material.dart';

import '../srs/sm2.dart';

class AppTheme {
  const AppTheme._();

  /// A muted slate-blue; readable at large sizes and calm enough to look at for
  /// a long review session.
  static const seed = Color(0xFF3F5B8B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: base.textTheme.copyWith(
        // The prompt on a flashcard.
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      ),
    );
  }

  /// Fixed colours for the four answer buttons, so "Again" is always the same
  /// red regardless of the active scheme.
  static Color ratingColor(Rating rating, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (rating) {
      Rating.again => dark ? const Color(0xFFE2756C) : const Color(0xFFC0392B),
      Rating.hard => dark ? const Color(0xFFE0A264) : const Color(0xFFB9701C),
      Rating.good => dark ? const Color(0xFF72A9D8) : const Color(0xFF2E6DA4),
      Rating.easy => dark ? const Color(0xFF7FBE8C) : const Color(0xFF2E7D4F),
    };
  }

  static String ratingLabel(Rating rating) => switch (rating) {
        Rating.again => 'Again',
        Rating.hard => 'Hard',
        Rating.good => 'Good',
        Rating.easy => 'Easy',
      };
}

/// Formats a scheduling delay the way the answer buttons show it: short,
/// approximate and never "0 days".
String formatInterval(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return '<1m';
  if (minutes < 60) return '${minutes}m';

  final hours = duration.inHours;
  if (hours < 24) return '${hours}h';

  final days = duration.inDays;
  if (days < 30) return '${days}d';
  if (days < 365) return '${(days / 30).round()}mo';
  final years = days / 365;
  return years < 10 ? '${years.toStringAsFixed(1)}y' : '${years.round()}y';
}
