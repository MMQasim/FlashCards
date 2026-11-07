/// Attribution for the bundled deck content.
///
/// The Goethe A1 deck is CC BY-SA 4.0, which requires that credit be given "in
/// any reasonable manner". A screen reachable from Settings is that manner;
/// without it the app would be out of compliance with the licence it relies on.
library;

import 'package:flutter/material.dart';

import '../../data/content_version.dart';

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Licences')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'DeutschCards bundles $bundledCardCount cards across '
            '$bundledDeckCount decks. Their sources and terms are below.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          _Section(
            title: 'Goethe A1 Wordlist',
            body: '"Goethe Institute A1 Wordlist" by patsytau, licensed under '
                'Creative Commons Attribution-ShareAlike 4.0 International '
                '(CC BY-SA 4.0).\n\n'
                'github.com/patsytau/anki_german_a1_vocab\n'
                'creativecommons.org/licenses/by-sa/4.0/\n\n'
                'This deck has been adapted for DeutschCards. The adapted deck '
                'content is offered under the same CC BY-SA 4.0 licence.\n\n'
                'The original wordlist is published by the Goethe-Institut.',
          ),

          _Section(
            title: 'Job and professional decks',
            body: 'Vocabulary selection for the job application and '
                'Berufsdeutsch decks follows "Menschen im Beruf: '
                'Bewerbungstraining" (Hueber Verlag).\n\n'
                'Words, translations, articles, plurals and conjugations are '
                'factual information. All example sentences in these decks were '
                'written for this app and are not reproduced from the book.',
          ),

          _Section(
            title: 'Remaining decks',
            body: 'The core vocabulary, IT verb family and noun/adjective '
                'family decks were compiled for this app.',
          ),

          _Section(
            title: 'Pronunciation',
            body: 'No audio is bundled. German is spoken by your device\'s own '
                'text-to-speech engine, so nothing is recorded, uploaded or '
                'redistributed.',
          ),

          const Divider(height: 36),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open-source packages'),
            subtitle: const Text('Licences for the libraries this app uses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'DeutschCards',
              applicationVersion: bundledContentVersion,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            body,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
