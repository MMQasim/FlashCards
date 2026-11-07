/// Renders one side of a flashcard.
library;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import 'speak_button.dart';

/// The prompt side: one large term, with a speaker when the prompt is German.
class CardPrompt extends StatelessWidget {
  const CardPrompt({required this.card, super.key});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // German prompts get the larger, quieter treatment; English prompts are
    // cues to produce German, so they are styled as a question.
    final style = card.front.length > 40
        ? theme.textTheme.headlineSmall
        : theme.textTheme.displaySmall;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageChip(language: card.frontLang),
        const SizedBox(height: 20),
        Text(card.front, style: style, textAlign: TextAlign.center),
        if (card.promptIsGerman) ...[
          const SizedBox(height: 8),
          SpeakButton(text: card.speakText ?? card.front, sentence: card.speakExample, size: 28),
        ],
      ],
    );
  }
}

/// The answer side: the solution, the example sentence and any detail rows.
class CardAnswer extends StatelessWidget {
  const CardAnswer({required this.card, super.key});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSpeaker = !card.promptIsGerman;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                card.back,
                style: card.back.length > 120
                    ? theme.textTheme.bodyLarge
                    : theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (showSpeaker)
              SpeakButton(
                text: card.speakText ?? card.back,
                sentence: card.speakExample,
                size: 26,
              ),
          ],
        ),
        if (card.exampleDe != null || card.exampleEn != null) ...[
          const SizedBox(height: 22),
          _ExampleBlock(card: card),
        ],
        if (card.details.isNotEmpty) ...[
          const SizedBox(height: 18),
          _DetailList(details: card.details),
        ],
      ],
    );
  }
}

class _ExampleBlock extends StatelessWidget {
  const _ExampleBlock({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (card.exampleDe != null)
                  Text(card.exampleDe!,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontStyle: FontStyle.italic)),
                if (card.exampleDe != null && card.exampleEn != null)
                  const SizedBox(height: 6),
                if (card.exampleEn != null)
                  Text(
                    card.exampleEn!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (card.exampleDe != null)
            SpeakButton(text: card.exampleDe, size: 20),
        ],
      ),
    );
  }
}

class _DetailList extends StatelessWidget {
  const _DetailList({required this.details});

  final List<CardDetail> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Short values read well as a compact two-column list; conjugation tables
    // and usage notes need the full width.
    final inline = details.where((d) => !d.isBlock).toList();
    final blocks = details.where((d) => d.isBlock).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inline.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final detail in inline)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: '${detail.label}: ',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: detail.value,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        if (blocks.isNotEmpty) ...[
          if (inline.isNotEmpty) const SizedBox(height: 12),
          for (final detail in blocks)
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: Text(detail.label, style: theme.textTheme.titleSmall),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      detail.value,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGerman = language == 'de';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isGerman ? 'Deutsch → English' : 'English → Deutsch',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
