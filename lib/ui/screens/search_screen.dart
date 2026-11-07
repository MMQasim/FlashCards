/// Search across every bundled card.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../data/models.dart';
import '../widgets/card_face.dart';
import '../widgets/speak_button.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Flashcard> _results = const [];
  bool _searching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Each keystroke would otherwise scan every card; 250ms is short enough to
    // feel immediate and long enough to skip most intermediate queries.
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _lastQuery = '';
      });
      return;
    }
    setState(() => _searching = true);
    final results = await context.read<AppDatabase>().search(trimmed, limit: 100);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      _lastQuery = trimmed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _controller,
              hintText: 'German or English word',
              leading: const Icon(Icons.search),
              trailing: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _run('');
                    },
                  ),
              ],
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _run,
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? _EmptyState(query: _lastQuery, theme: theme)
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final card = _results[index];
                      return ListTile(
                        title: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.back.replaceAll('\n', '  ·  '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (card.deckName != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                card.deckName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: SpeakButton(
                          text: card.primarySpeech,
                          sentence: card.speakExample,
                          size: 20,
                        ),
                        onTap: () => _show(context, card),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _show(BuildContext context, Flashcard card) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, required this.theme});

  final String query;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final noMatches = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              noMatches ? Icons.search_off : Icons.search,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              noMatches ? 'Nothing matches "$query"' : 'Look up any word',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              noMatches
                  ? 'Try a shorter word or the other language.'
                  : 'Umlauts are optional - "uber" finds "über".',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
