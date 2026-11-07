/// Deck detail: progress, per-deck limits and a browsable card list.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import '../../state/library_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/card_face.dart';
import '../widgets/speak_button.dart';
import 'study_screen.dart';

class DeckDetailScreen extends StatefulWidget {
  const DeckDetailScreen({required this.deck, super.key});

  final Deck deck;

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  static const _pageSize = 60;

  final _cards = <StudyCard>[];
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false;
  DeckProgress _progress = DeckProgress.empty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = context.read<AppDatabase>();
    final progress = await db.deckProgress(widget.deck.id, DateTime.now());
    final page = await db.browseDeck(widget.deck.id, limit: _pageSize);
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _cards
        ..clear()
        ..addAll(page);
      _exhausted = page.length < _pageSize;
      _loading = false;
    });
  }

  void _maybeLoadMore() {
    if (_loadingMore || _exhausted) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 400) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final page = await context
        .read<AppDatabase>()
        .browseDeck(widget.deck.id, limit: _pageSize, offset: _cards.length);
    if (!mounted) return;
    setState(() {
      _cards.addAll(page);
      _exhausted = page.length < _pageSize;
      _loadingMore = false;
    });
  }

  Future<void> _study() async {
    final settings = context.read<SettingsController>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyScreen(
          deck: widget.deck,
          newLimit: settings.newPerDay,
          reviewLimit: settings.reviewsPerDay,
        ),
      ),
    );
    await _load();
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset ${widget.deck.name}?'),
        content: const Text(
          'This erases your scheduling and review history for every card in '
          'this deck. Other decks are not affected. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<LibraryController>().resetDeck(widget.deck.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _confirmReset();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset progress')),
            ],
          ),
        ],
      ),
      floatingActionButton: _progress.dueNow > 0 || _progress.newCards > 0
          ? FloatingActionButton.extended(
              onPressed: _study,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Study'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _cards.length + 1,
              separatorBuilder: (_, index) =>
                  index == 0 ? const SizedBox.shrink() : const Divider(),
              itemBuilder: (context, index) {
                if (index == 0) return _Header(deck: widget.deck, progress: _progress);
                final item = _cards[index - 1];
                return _CardRow(item: item);
              },
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.deck, required this.progress});

  final Deck deck;
  final DeckProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (deck.description != null)
            Text(
              deck.description!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(label: 'Total', value: '${progress.total}'),
              _Stat(label: 'New', value: '${progress.newCards}'),
              _Stat(label: 'Due', value: '${progress.dueNow}'),
              _Stat(label: 'Known', value: '${progress.known}'),
            ],
          ),
          const SizedBox(height: 18),
          Text('All cards', style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.item});

  final StudyCard item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = item.card;
    final state = item.state;

    return ListTile(
      title: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        card.back.replaceAll('\n', '  ·  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!state.isNew)
            Text(
              state.isGraduated ? '${state.intervalDays}d' : 'learn',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          SpeakButton(text: card.primarySpeech, sentence: card.speakExample, size: 20),
        ],
      ),
      onTap: () => _showCard(context, card),
    );
  }

  void _showCard(BuildContext context, Flashcard card) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            CardPrompt(card: card),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 20),
            CardAnswer(card: card),
          ],
        ),
      ),
    );
  }
}
