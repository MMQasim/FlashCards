/// Pronounces the German side of a card using the device's TTS engine.
///
/// Tap reads the term; a long press reads the term and then its example
/// sentence. When no German voice is installed the button stays visible but
/// explains what to do instead of failing silently.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/speech_service.dart';

class SpeakButton extends StatelessWidget {
  const SpeakButton({
    required this.text,
    this.sentence,
    this.size = 24,
    super.key,
  });

  /// The German term to read out.
  final String? text;

  /// An example sentence, spoken after [text] on a long press.
  final String? sentence;

  final double size;

  @override
  Widget build(BuildContext context) {
    final speech = context.watch<SpeechService>();
    if (text == null || text!.trim().isEmpty) return const SizedBox.shrink();

    final unavailable = !speech.canSpeak;
    final hasSentence = sentence != null && sentence!.trim().isNotEmpty;

    return Tooltip(
      message: unavailable
          ? 'German speech is unavailable'
          : hasSentence
              ? 'Tap for the word, hold for the sentence'
              : 'Hear the pronunciation',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (unavailable) {
            _explainUnavailable(context, speech);
            return;
          }
          speech.isSpeaking ? speech.stop() : speech.speak(text);
        },
        onLongPress: unavailable || !hasSentence
            ? null
            : () => speech.speakSequence([text, sentence]),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            speech.isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
            size: size,
            color: unavailable
                ? Theme.of(context).disabledColor
                : Theme.of(context).colorScheme.primary,
            semanticLabel: 'Pronounce in German',
          ),
        ),
      ),
    );
  }

  void _explainUnavailable(BuildContext context, SpeechService speech) {
    final message = switch (speech.status) {
      SpeechStatus.missingGermanVoice =>
        'No German voice is installed. Add one under System settings > '
            'Languages & input > Text-to-speech output.',
      SpeechStatus.unavailable =>
        'This device has no usable text-to-speech engine.',
      _ => speech.isEnabled
          ? 'Speech is still starting up.'
          : 'Speech is switched off in Settings.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }
}
