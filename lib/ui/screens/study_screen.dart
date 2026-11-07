/// A study session for one deck.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../services/speech_service.dart';
import '../../srs/sm2.dart';
import '../../state/settings_controller.dart';
import '../../state/study_controller.dart';
import '../widgets/card_face.dart';
import '../widgets/rating_buttons.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({
    required this.deck,
    required this.newLimit,
    required this.reviewLimit,
    super.key,
  });

  final Deck deck;
  final int newLimit;
  final int reviewLimit;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late final StudyController _controller;
  late final SpeechService _speech;
  late final SettingsController _settings;
  int _totalAtStart = 0;

  @override
  void initState() {
    super.initState();
    _speech = context.read<SpeechService>();
    _settings = context.read<SettingsController>();
    _controller = StudyController(
      database: context.read<AppDatabase>(),
      deck: widget.deck,
      newLimit: widget.newLimit,
      reviewLimit: widget.reviewLimit,
    )..addListener(_onControllerChanged);
    _controller.start().then((_) {
      if (mounted) setState(() => _totalAtStart = _controller.remaining);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onControllerChanged() {
    final message = _controller.error;
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      _controller.dismissError();
    }
  }

  void _reveal() {
    _controller.reveal();
    final card = _controller.current?.card;
    if (card != null && _settings.speakOnReveal) {
      // Reading the German side on reveal is the main reason the app has audio:
      // the learner hears the word at the moment they check themselves.
      _speech.speak(card.speakText ?? (card.promptIsGerman ? card.front : card.back));
    }
  }

  Future<void> _rate(Rating rating) async {
    await _speech.stop();
    await _controller.answer(rating);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final phase = _controller.phase;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.deck.name, overflow: TextOverflow.ellipsis),
            actions: [
              if (_controller.canUndo)
                IconButton(
                  tooltip: 'Undo last answer',
                  onPressed: _controller.undo,
                  icon: const Icon(Icons.undo),
                ),
            ],
            bottom: phase == SessionPhase.studying
                ? _SessionProgress(
                    done: _controller.tally.answered,
                    remaining: _controller.remaining,
                    totalAtStart: _totalAtStart,
                  )
                : null,
          ),
          body: switch (phase) {
            SessionPhase.loading => const Center(child: CircularProgressIndicator()),
            SessionPhase.failed => _Message(
                icon: Icons.error_outline,
                title: 'Could not start this session',
                body: _controller.error ?? 'Unknown error',
                actionLabel: 'Try again',
                onAction: _controller.start,
              ),
            SessionPhase.empty => _Message(
                icon: Icons.check_circle_outline,
                title: 'Nothing due in this deck',
                body: 'Come back when cards fall due, or add more new cards '
                    'for today from this deck.',
                actionLabel: 'Study 10 new cards',
                onAction: () => _controller.extend(extraNew: 10),
              ),
            SessionPhase.finished => _SessionSummary(
                tally: _controller.tally,
                onMore: () => _controller.extend(extraNew: 10),
                onDone: () => Navigator.of(context).pop(),
              ),
            SessionPhase.studying => _StudyBody(
                controller: _controller,
                onReveal: _reveal,
                onRate: _rate,
                showIntervals: _settings.showIntervals,
              ),
          },
        );
      },
    );
  }
}

class _StudyBody extends StatelessWidget {
  const _StudyBody({
    required this.controller,
    required this.onReveal,
    required this.onRate,
    required this.showIntervals,
  });

  final StudyController controller;
  final VoidCallback onReveal;
  final ValueChanged<Rating> onRate;
  final bool showIntervals;

  @override
  Widget build(BuildContext context) {
    final studyCard = controller.current;
    if (studyCard == null) return const SizedBox.shrink();
    final card = studyCard.card;
    final revealed = controller.isRevealed;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              // Tapping anywhere on the card reveals it, which is faster than
              // reaching for the button on a large phone.
              onTap: revealed ? null : onReveal,
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    _PhaseChip(state: studyCard.state),
                    const SizedBox(height: 24),
                    CardPrompt(card: card),
                    if (revealed) ...[
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 24),
                      CardAnswer(card: card),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: revealed
                ? RatingButtons(
                    onRate: onRate,
                    intervals: controller.intervalPreview,
                    showIntervals: showIntervals,
                  )
                : RevealButton(onPressed: onReveal),
          ),
        ],
      ),
    );
  }
}

/// Shows whether the current card is new, in learning, or a scheduled review.
class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.state});

  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String label, Color color) = switch (state.phase) {
      CardPhase.isNew => ('New', theme.colorScheme.tertiary),
      CardPhase.learning => ('Learning', theme.colorScheme.secondary),
      CardPhase.relearning => ('Relearning', theme.colorScheme.error),
      CardPhase.review => (
          'Review · ${state.intervalDays}d',
          theme.colorScheme.primary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.3),
      ),
    );
  }
}

class _SessionProgress extends StatelessWidget implements PreferredSizeWidget {
  const _SessionProgress({
    required this.done,
    required this.remaining,
    required this.totalAtStart,
  });

  final int done;
  final int remaining;
  final int totalAtStart;

  @override
  Size get preferredSize => const Size.fromHeight(26);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = (done + remaining).clamp(1, 1 << 30);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$remaining left',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.tally,
    required this.onMore,
    required this.onDone,
  });

  final SessionTally tally;
  final VoidCallback onMore;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 18),
            Text('Session complete', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${tally.answered} answered · '
              '${(tally.accuracy * 100).round()}% recalled'
              '${tally.newIntroduced > 0 ? ' · ${tally.newIntroduced} new' : ''}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in <(String, int)>[
                  ('Again', tally.again),
                  ('Hard', tally.hard),
                  ('Good', tally.good),
                  ('Easy', tally.easy),
                ])
                  Chip(label: Text('${entry.$1}: ${entry.$2}')),
              ],
            ),
            const SizedBox(height: 36),
            FilledButton(onPressed: onMore, child: const Text('Study 10 more')),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onDone, child: const Text('Back to decks')),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 26),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to decks'),
            ),
          ],
        ),
      ),
    );
  }
}
