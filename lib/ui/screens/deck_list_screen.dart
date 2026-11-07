/// Home screen: every bundled deck with its progress.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/deck_tile.dart';
import 'deck_detail_screen.dart';
import 'study_screen.dart';

class DeckListScreen extends StatelessWidget {
  const DeckListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DeutschCards'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: library.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: switch (library) {
        LibraryController(isLoading: true) =>
          const Center(child: CircularProgressIndicator()),
        LibraryController(error: final String message) => _ErrorState(
            message: message,
            onRetry: library.load,
          ),
        _ => RefreshIndicator(
            onRefresh: library.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _TodayHeader(library: library),
                const SizedBox(height: 20),
                for (final deck in library.decks) ...[
                  DeckTile(
                    deck: deck,
                    progress: library.progressFor(deck.id),
                    onStudy: () => _study(context, deck),
                    onOpen: () => _open(context, deck),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
      },
    );
  }

  Future<void> _study(BuildContext context, Deck deck) async {
    final settings = context.read<SettingsController>();
    final library = context.read<LibraryController>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyScreen(
          deck: deck,
          newLimit: settings.newPerDay,
          reviewLimit: settings.reviewsPerDay,
        ),
      ),
    );
    await library.refresh();
  }

  Future<void> _open(BuildContext context, Deck deck) async {
    final library = context.read<LibraryController>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DeckDetailScreen(deck: deck)),
    );
    await library.refresh();
  }
}

/// Streak, cards answered today and the total waiting across all decks.
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = library.totalDue;
    final unseen = library.totalNew;

    // "Nothing due" would be misleading while thousands of cards have never
    // been seen: due means scheduled, not that there is nothing left to learn.
    final (String headline, String subtitle) = switch ((due, unseen)) {
      (0, 0) => (
          'You are all caught up',
          'Every card is scheduled for a future day. Enjoy the break.',
        ),
      (0, _) => (
          'Nothing scheduled yet',
          'Pick a deck below to start learning new words.',
        ),
      _ => ('\$due cards waiting', 'Pick a deck below to carry on.'),
    };

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(
                  icon: Icons.local_fire_department_outlined,
                  value: '${library.streak}',
                  label: library.streak == 1 ? 'day streak' : 'day streak',
                ),
                const SizedBox(width: 24),
                _Metric(
                  icon: Icons.check_circle_outline,
                  value: '${library.reviewsToday}',
                  label: 'today',
                ),
                const SizedBox(width: 24),
                _Metric(
                  icon: Icons.school_outlined,
                  value: '${library.totalKnown}',
                  label: 'known',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Row(
      children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: color.withValues(alpha: 0.75))),
          ],
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
