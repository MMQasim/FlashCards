/// A fake `flutter_tts` platform channel for widget tests.
///
/// The real plugin needs an Android TTS engine, so the method channel is
/// answered in-process instead. Calls are recorded so a test can assert that
/// revealing a card actually asked the engine to speak.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTts {
  FakeTts({this.languages = const ['en-US', 'de-DE', 'fr-FR']});

  static const _channel = MethodChannel('flutter_tts');

  /// Locales the fake engine reports as installed.
  final List<String> languages;

  /// Every method call made by the app, in order.
  final List<MethodCall> calls = [];

  /// Text passed to `speak`, in order.
  List<String> get spokenText => calls
      .where((c) => c.method == 'speak')
      .map((c) => c.arguments.toString())
      .toList();

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getLanguages' => languages,
        'getDefaultEngine' => 'com.fake.tts',
        'getEngines' => ['com.fake.tts'],
        'awaitSpeakCompletion' => 1,
        'setLanguage' => 1,
        'setSpeechRate' => 1,
        'setPitch' => 1,
        'speak' => 1,
        'stop' => 1,
        'isLanguageAvailable' => true,
        _ => null,
      };
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}
