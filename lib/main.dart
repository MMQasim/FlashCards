/// DeutschCards - German flashcards with spaced repetition and speech.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/content_asset.dart';
import 'data/content_version.dart';
import 'services/speech_service.dart';
import 'state/library_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

/// Opens the database and probes the speech engine before showing the app.
///
/// Both are needed by every screen, so they are resolved once here rather than
/// guarded for null throughout the widget tree. A failure is shown as a
/// retryable screen instead of a blank window.
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppServices> _startup;

  /// True while the one-time extraction of the bundled decks is running.
  bool _firstRun = false;

  @override
  void initState() {
    super.initState();
    _startup = _start();
  }

  Future<AppServices> _start() async {
    final directory = await getApplicationSupportDirectory();

    // Unpacking 13 MB of deck content takes a few seconds and happens only on
    // a first launch or after an update ships new decks. Say so, rather than
    // leaving an unexplained spinner on screen.
    if (await ContentAsset.needsExtraction(directory) && mounted) {
      setState(() => _firstRun = true);
    }

    final database = await AppDatabase.open(directory: directory);

    final speech = SpeechService();
    final settings = SettingsController(database: database, speech: speech);
    final library = LibraryController(database: database);

    // Settings first: it restores the saved speech rate that the probe applies.
    await settings.load();
    await library.load();

    // Deliberately not awaited. Probing the text-to-speech engine crosses a
    // process boundary and can take over a second; the deck list does not need
    // it, and every speech control listens to SpeechService, so they enable
    // themselves once the probe finishes. Awaiting it here would hold the whole
    // app on the loading screen for a feature the first screen never uses.
    unawaited(speech.initialise());

    return AppServices(
      database: database,
      speech: speech,
      settings: settings,
      library: library,
    );
  }

  void _retry() => setState(() {
        _firstRun = false;
        _startup = _start();
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupFailure(error: snapshot.error!, onRetry: _retry);
        }
        if (!snapshot.hasData) return _SplashScreen(firstRun: _firstRun);
        return DeutschCardsApp(services: snapshot.data!);
      },
    );
  }
}

/// The services every screen needs, resolved once at startup.
class AppServices {
  const AppServices({
    required this.database,
    required this.speech,
    required this.settings,
    required this.library,
  });

  final AppDatabase database;
  final SpeechService speech;
  final SettingsController settings;
  final LibraryController library;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({this.firstRun = false});

  /// Shows the one-time setup wording instead of a plain loading message.
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              Text(
                firstRun ? 'Setting up your decks' : 'Loading',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (firstRun) ...[
                const SizedBox(height: 6),
                Text(
                  'Unpacking ${NumberFormat.decimalPattern().format(bundledCardCount)}'
                  ' cards. This happens once.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 16),
                Text('DeutschCards could not start',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text('$error', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
