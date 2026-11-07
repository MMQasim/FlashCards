/// German text-to-speech, backed by the Android TTS engine.
///
/// The app ships no audio files. Pronunciation comes from the engine already on
/// the device, which keeps the download small and means every deck has audio,
/// including the ones whose Anki source had no recordings.
///
/// German voice data is not guaranteed to be installed, so [status] reports what
/// was actually found and the UI offers to open the system settings when it is
/// missing, rather than failing silently on every tap.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum SpeechStatus {
  /// Not probed yet.
  unknown,

  /// A German voice is available.
  ready,

  /// The engine works but has no German voice installed.
  missingGermanVoice,

  /// No usable engine at all.
  unavailable,
}

/// Preferred German locales, most specific first.
const _germanLocales = <String>['de-DE', 'de_DE', 'de-AT', 'de-CH', 'de'];

class SpeechService extends ChangeNotifier {
  SpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  SpeechStatus _status = SpeechStatus.unknown;
  String? _resolvedLocale;
  bool _speaking = false;
  bool _enabled = true;
  double _rate = 0.45;
  double _pitch = 1.0;
  Completer<void>? _pending;

  SpeechStatus get status => _status;
  String? get resolvedLocale => _resolvedLocale;
  bool get isSpeaking => _speaking;
  bool get isEnabled => _enabled;

  /// Speech rate on the platform's own 0..1 scale. 0.45 is close to a natural
  /// pace for German on Android, where 1.0 is roughly double speed.
  double get rate => _rate;
  double get pitch => _pitch;

  bool get canSpeak => _enabled && _status == SpeechStatus.ready;

  /// Probes the engine and selects a German voice. Safe to call more than once.
  Future<void> initialise() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      final locale = await _pickGermanLocale();

      if (locale == null) {
        _status = SpeechStatus.missingGermanVoice;
        debugPrint('SpeechService: no German voice available');
      } else {
        _resolvedLocale = locale;
        await _tts.setLanguage(locale);
        await _tts.setSpeechRate(_rate);
        await _tts.setPitch(_pitch);
        _status = SpeechStatus.ready;
        debugPrint('SpeechService: using $locale');
      }

      _tts.setCompletionHandler(_finish);
      _tts.setCancelHandler(_finish);
      _tts.setErrorHandler((message) {
        debugPrint('SpeechService error: $message');
        _finish();
      });
    } on Exception catch (error) {
      // A missing or broken engine must not stop the app from starting; cards
      // are still perfectly studiable without audio.
      _status = SpeechStatus.unavailable;
      debugPrint('SpeechService unavailable: $error');
    }
    notifyListeners();
  }

  Future<String?> _pickGermanLocale() async {
    final raw = await _tts.getLanguages;
    if (raw is! List) return null;
    final available = raw.map((e) => e.toString()).toList();
    final normalised = {
      for (final locale in available) locale.toLowerCase().replaceAll('_', '-'): locale,
    };

    for (final candidate in _germanLocales) {
      final match = normalised[candidate.toLowerCase().replaceAll('_', '-')];
      if (match != null) return match;
    }
    // Any German variant will do if none of the preferred ones are present.
    final anyGerman = normalised.entries
        .firstWhere((e) => e.key.startsWith('de'), orElse: () => const MapEntry('', ''));
    return anyGerman.value.isEmpty ? null : anyGerman.value;
  }

  /// Speaks [text] in German, cancelling anything already playing.
  ///
  /// Awaits completion so callers can chain a term and then its example
  /// sentence without the second cutting off the first.
  Future<void> speak(String? text) async {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty || !canSpeak) return;

    await stop();
    _speaking = true;
    notifyListeners();

    final completer = Completer<void>();
    _pending = completer;
    try {
      await _tts.speak(_prepare(trimmed));
    } on Exception catch (error) {
      debugPrint('SpeechService: speak failed: $error');
      _finish();
      return;
    }
    // awaitSpeakCompletion(true) makes speak() itself wait on Android, but the
    // handlers are the authority on whether playback really ended.
    if (!completer.isCompleted) _finish();
  }

  /// Speaks a term and then its example sentence, with a short gap.
  Future<void> speakSequence(Iterable<String?> parts) async {
    for (final part in parts) {
      if (part == null || part.trim().isEmpty) continue;
      await speak(part);
      if (!canSpeak) return;
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
  }

  Future<void> stop() async {
    if (!_speaking) return;
    try {
      await _tts.stop();
    } on Exception catch (error) {
      debugPrint('SpeechService: stop failed: $error');
    }
    _finish();
  }

  void _finish() {
    _speaking = false;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
    notifyListeners();
  }

  /// Strips the bits of card text that read badly out loud.
  ///
  /// Source decks write plurals as "die Ansage, -n" and gloss alternatives with
  /// slashes; speaking those literally produces "die Ansage comma dash en".
  String _prepare(String text) {
    var out = text.replaceAll(RegExp(r',\s*-\w*'), '');
    out = out.replaceAll(RegExp(r'\(.*?\)'), ' ');
    out = out.replaceAll('/', ' oder ');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out.trim();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) await stop();
    notifyListeners();
  }

  Future<void> setRate(double value) async {
    _rate = value.clamp(0.1, 1.0);
    if (_status == SpeechStatus.ready) await _tts.setSpeechRate(_rate);
    notifyListeners();
  }

  Future<void> setPitch(double value) async {
    _pitch = value.clamp(0.5, 2.0);
    if (_status == SpeechStatus.ready) await _tts.setPitch(_pitch);
    notifyListeners();
  }

  /// Opens the system screen where German voice data can be installed.
  Future<void> openEngineSettings() async {
    try {
      // Available on Android; a no-op elsewhere.
      await _tts.setEngine(await _tts.getDefaultEngine ?? '');
    } on Exception catch (error) {
      debugPrint('SpeechService: could not reach engine settings: $error');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
