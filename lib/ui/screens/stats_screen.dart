/// Progress screen: streak, recent activity and the upcoming review load.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../state/library_controller.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<DailyActivity>? _activity;
  List<int>? _forecast;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final library = context.read<LibraryController>();
    final activity = await library.activity(days: 30);
    final forecast = await library.forecast(days: 14);
    if (!mounted) return;
    setState(() {
      _activity = activity;
      _forecast = forecast;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await library.refresh();
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _SummaryGrid(library: library),
                  const SizedBox(height: 24),
                  _SectionTitle('Last 30 days'),
                  const SizedBox(height: 12),
                  _ActivityChart(activity: _activity ?? const []),
                  const SizedBox(height: 28),
                  _SectionTitle('Coming up'),
                  const SizedBox(height: 12),
                  _ForecastChart(forecast: _forecast ?? const []),
                  const SizedBox(height: 28),
                  _SectionTitle('By deck'),
                  const SizedBox(height: 4),
                  for (final deck in library.decks)
                    _DeckProgressRow(
                      name: deck.name,
                      progress: library.progressFor(deck.id),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'A card counts as known once its review interval reaches 21 days.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final known = library.totalKnown;
    final total = library.totalCards;
    final percent = total == 0 ? 0 : (known / total * 100).round();

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '${library.streak}',
            label: 'day streak',
            icon: Icons.local_fire_department_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '${library.reviewsToday}',
            label: 'answered today',
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '$percent%',
            label: '$known of $total known',
            icon: Icons.school_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reviews answered per day, drawn as bars scaled to the busiest day.
class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.activity});

  final List<DailyActivity> activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (activity.isEmpty) return const SizedBox.shrink();

    final peak = activity.fold<int>(0, (max, d) => d.reviews > max ? d.reviews : max);
    if (peak == 0) {
      return _EmptyChart(
        message: 'No reviews yet. Answer a few cards and they will show up here.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          children: [
            SizedBox(
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in activity)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Tooltip(
                          message: '${day.reviews} on '
                              '${day.day.day}/${day.day.month}',
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: day.reviews == 0
                                    ? 2
                                    : (day.reviews / peak * 88).clamp(4, 88),
                                decoration: BoxDecoration(
                                  color: day.reviews == 0
                                      ? theme.colorScheme.surfaceContainerHighest
                                      : theme.colorScheme.primary.withValues(
                                          alpha: 0.45 + 0.55 * day.accuracy,
                                        ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('30 days ago', style: theme.textTheme.labelSmall),
                Text('peak $peak', style: theme.textTheme.labelSmall),
                Text('today', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// How many cards fall due on each of the next two weeks' days.
class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.forecast});

  final List<int> forecast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (forecast.isEmpty) return const SizedBox.shrink();
    final peak = forecast.fold<int>(0, (max, v) => v > max ? v : max);
    if (peak == 0) {
      return _EmptyChart(message: 'Nothing scheduled yet.');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          children: [
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < forecast.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              forecast[i] == 0 ? '' : '${forecast[i]}',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              height: forecast[i] == 0
                                  ? 2
                                  : (forecast[i] / peak * 52).clamp(4, 52),
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.primary.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('today', style: theme.textTheme.labelSmall),
                Text('in ${forecast.length} days', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _DeckProgressRow extends StatelessWidget {
  const _DeckProgressRow({required this.name, required this.progress});

  final String name;
  final DeckProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
              Text(
                '${progress.known}/${progress.total}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.knownRatio,
              minHeight: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
