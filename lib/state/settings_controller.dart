/// User preferences, persisted in the review database's `setting` table.
library;

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/models.dart' show DeckProgress;
import '../services/speech_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({required AppDatabase database, required SpeechService speech})
      : _db = database,
        _speech = speech;

  static const _kThemeMode = 'theme_mode';
  static const _kNewPerDay = 'new_per_day';
  static const _kReviewsPerDay = 'reviews_per_day';
  static const _kSpeakOnReveal = 'speak_on_reveal';
  static const _kSpeechEnabled = 'speech_enabled';
  static const _kSpeechRate = 'speech_rate';
  static const _kShowIntervals = 'show_intervals';

  final AppDatabase _db;
  final SpeechService _speech;

  ThemeMode _themeMode = ThemeMode.system;
  int _newPerDay = 20;
  int _reviewsPerDay = 200;
  bool _speakOnReveal = true;
  bool _showIntervals = true;

  ThemeMode get themeMode => _themeMode;
  int get newPerDay => _newPerDay;
  int get reviewsPerDay => _reviewsPerDay;

  /// Pronounce the German side automatically when the answer is revealed.
  bool get speakOnReveal => _speakOnReveal;

  /// Show the next interval under each answer button.
  bool get showIntervals => _showIntervals;

  Future<void> load() async {
    _themeMode = switch (await _db.settingValue(_kThemeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _newPerDay = int.tryParse(await _db.settingValue(_kNewPerDay) ?? '') ?? 20;
    _reviewsPerDay =
        int.tryParse(await _db.settingValue(_kReviewsPerDay) ?? '') ?? 200;
    _speakOnReveal = (await _db.settingValue(_kSpeakOnReveal) ?? '1') == '1';
    _showIntervals = (await _db.settingValue(_kShowIntervals) ?? '1') == '1';

    await _speech.setEnabled((await _db.settingValue(_kSpeechEnabled) ?? '1') == '1');
    final rate = double.tryParse(await _db.settingValue(_kSpeechRate) ?? '');
    if (rate != null) await _speech.setRate(rate);

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _db.setSetting(_kThemeMode, mode.name);
  }

  Future<void> setNewPerDay(int value) async {
    _newPerDay = value.clamp(0, 200);
    notifyListeners();
    await _db.setSetting(_kNewPerDay, '$_newPerDay');
  }

  Future<void> setReviewsPerDay(int value) async {
    _reviewsPerDay = value.clamp(10, 9999);
    notifyListeners();
    await _db.setSetting(_kReviewsPerDay, '$_reviewsPerDay');
  }

  Future<void> setSpeakOnReveal(bool value) async {
    _speakOnReveal = value;
    notifyListeners();
    await _db.setSetting(_kSpeakOnReveal, value ? '1' : '0');
  }

  Future<void> setShowIntervals(bool value) async {
    _showIntervals = value;
    notifyListeners();
    await _db.setSetting(_kShowIntervals, value ? '1' : '0');
  }

  Future<void> setSpeechEnabled(bool value) async {
    await _speech.setEnabled(value);
    notifyListeners();
    await _db.setSetting(_kSpeechEnabled, value ? '1' : '0');
  }

  Future<void> setSpeechRate(double value) async {
    await _speech.setRate(value);
    notifyListeners();
    await _db.setSetting(_kSpeechRate, value.toStringAsFixed(2));
  }
}

/// Convenience for the home header.
extension ProgressSummary on DeckProgress {
  String get summary => '$newCards new · $dueNow due · $known known';
}
