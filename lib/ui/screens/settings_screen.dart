/// Settings: study limits, speech and appearance.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_version.dart';
import '../../services/speech_service.dart';
import '../../state/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final speech = context.watch<SpeechService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionHeader('Daily study'),
          _StepperTile(
            title: 'New cards per day',
            subtitle: 'Per deck, per session',
            value: settings.newPerDay,
            min: 0,
            max: 100,
            step: 5,
            onChanged: settings.setNewPerDay,
          ),
          _StepperTile(
            title: 'Maximum reviews',
            subtitle: 'Cap on due cards per session',
            value: settings.reviewsPerDay,
            min: 20,
            max: 500,
            step: 20,
            onChanged: settings.setReviewsPerDay,
          ),
          SwitchListTile(
            title: const Text('Show next interval'),
            subtitle: const Text('Display when each answer schedules the card'),
            value: settings.showIntervals,
            onChanged: settings.setShowIntervals,
          ),

          const Divider(height: 32),
          const _SectionHeader('Pronunciation'),
          _SpeechStatusTile(speech: speech),
          SwitchListTile(
            title: const Text('German speech'),
            subtitle: const Text('Use the device text-to-speech engine'),
            value: speech.isEnabled,
            onChanged: speech.status == SpeechStatus.unavailable
                ? null
                : settings.setSpeechEnabled,
          ),
          SwitchListTile(
            title: const Text('Speak on reveal'),
            subtitle: const Text('Read the German word when the answer is shown'),
            value: settings.speakOnReveal,
            onChanged: speech.isEnabled ? settings.setSpeakOnReveal : null,
          ),
          ListTile(
            title: const Text('Speech speed'),
            subtitle: Slider(
              value: speech.rate,
              min: 0.2,
              max: 0.9,
              divisions: 14,
              label: '${(speech.rate * 100).round()}%',
              onChanged: speech.isEnabled ? settings.setSpeechRate : null,
            ),
            trailing: IconButton(
              tooltip: 'Test',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: speech.canSpeak
                  ? () => speech.speak('Guten Tag. Ich lerne Deutsch mit DeutschCards.')
                  : null,
            ),
          ),

          const Divider(height: 32),
          const _SectionHeader('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) settings.setThemeMode(mode);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('Match system'),
                ),
                RadioListTile<ThemeMode>(value: ThemeMode.light, title: Text('Light')),
                RadioListTile<ThemeMode>(value: ThemeMode.dark, title: Text('Dark')),
              ],
            ),
          ),

          const Divider(height: 32),
          const _SectionHeader('About'),
          ListTile(
            title: const Text('Card collection'),
            subtitle: Text('$bundledCardCount cards in $bundledDeckCount decks'),
          ),
          ListTile(
            title: const Text('Content version'),
            subtitle: Text(bundledContentVersion),
          ),
          const ListTile(
            title: Text('Offline'),
            subtitle: Text(
              'Every deck is bundled with the app. Nothing is uploaded and no '
              'account is needed.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeechStatusTile extends StatelessWidget {
  const _SpeechStatusTile({required this.speech});

  final SpeechService speech;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String title, String body) = switch (speech.status) {
      SpeechStatus.ready => (
          Icons.check_circle_outline,
          'German voice ready',
          'Using ${speech.resolvedLocale}',
        ),
      SpeechStatus.missingGermanVoice => (
          Icons.warning_amber_outlined,
          'No German voice installed',
          'Install one under System settings > Languages & input > '
              'Text-to-speech output, then reopen the app.',
        ),
      SpeechStatus.unavailable => (
          Icons.volume_off_outlined,
          'No speech engine',
          'This device has no usable text-to-speech engine. Cards still work '
              'without audio.',
        ),
      SpeechStatus.unknown => (
          Icons.hourglass_empty,
          'Checking for a German voice',
          'This takes a moment on first launch.',
        ),
    };

    final warn = speech.status == SpeechStatus.missingGermanVoice ||
        speech.status == SpeechStatus.unavailable;

    return ListTile(
      leading: Icon(icon, color: warn ? theme.colorScheme.error : theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(body),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// A numeric setting with minus/plus buttons, which is easier to hit than a
/// slider for values that matter exactly.
class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value <= min ? null : () => onChanged(value - step),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + step),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
