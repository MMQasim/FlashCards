/// One deck in the deck list, with its counts and progress.
library;

import 'package:flutter/material.dart';

import '../../data/models.dart';

class DeckTile extends StatelessWidget {
  const DeckTile({
    required this.deck,
    required this.progress,
    required this.onStudy,
    required this.onOpen,
    super.key,
  });

  final Deck deck;
  final DeckProgress progress;
  final VoidCallback onStudy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = progress.dueNow;
    final hasWork = due > 0 || progress.newCards > 0;

    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(deck.name,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            if (deck.level != null) _LevelBadge(level: deck.level!),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${progress.total} cards',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ProgressBar(progress: progress),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Count(
                    label: 'due',
                    value: due,
                    emphasised: due > 0,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  _Count(
                    label: 'new',
                    value: progress.newCards,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                  _Count(
                    label: 'known',
                    value: progress.known,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: hasWork ? onStudy : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(96, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Text(hasWork ? 'Study' : 'Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three-segment bar: known, seen-but-not-yet-known, untouched.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final DeckProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = progress.total == 0 ? 1 : progress.total;
    final known = progress.known / total;
    final learning = (progress.studiedCards - progress.known).clamp(0, total) / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (known > 0)
              Expanded(
                flex: (known * 1000).round(),
                child: ColoredBox(color: theme.colorScheme.primary),
              ),
            if (learning > 0)
              Expanded(
                flex: (learning * 1000).round(),
                child: ColoredBox(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
            Expanded(
              flex: ((1 - known - learning).clamp(0.0, 1.0) * 1000).round() + 1,
              child: ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.label,
    required this.value,
    required this.color,
    this.emphasised = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$value',
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: emphasised ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
