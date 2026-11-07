@TestOn('vm')
library;

import 'dart:io';

import 'package:deutschcards/data/app_database.dart';
import 'package:deutschcards/data/content_asset.dart';
import 'package:deutschcards/data/models.dart';
import 'package:deutschcards/services/speech_service.dart';
import 'package:deutschcards/state/library_controller.dart';
import 'package:deutschcards/state/settings_controller.dart';
import 'package:deutschcards/ui/screens/deck_list_screen.dart';
import 'package:deutschcards/ui/screens/search_screen.dart';
import 'package:deutschcards/ui/screens/study_screen.dart';
import 'package:deutschcards/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'support/fake_tts.dart';
import 'support/sqlite_test_setup.dart';

void main() {
  late Directory temp;
  late AppDatabase db;
  late SpeechService speech;
  late SettingsController settings;
  late LibraryController library;
  late FakeTts tts;

  setUpAll(initSqliteForTests);

  setUp(() async {
    tts = FakeTts()..install();
    temp = await Directory.systemTemp.createTemp('deutschcards-widget-');
    db = await AppDatabase.open(
      directory: temp,
      ensureContent: (dir) async {
        final target = p.join(dir.path, ContentAsset.fileName);
        await File('assets/content/content.db').copy(target);
        return target;
      },
    );
    speech = SpeechService();
    settings = SettingsController(database: db, speech: speech);
    library = LibraryController(database: db);
    await settings.load();
    await speech.initialise();
    await library.load();
  });

  tearDown(() async {
    tts.remove();
    await db.close();
    await temp.delete(recursive: true);
  });

  Widget wrap(Widget child) => MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider<SpeechService>.value(value: speech),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<LibraryController>.value(value: library),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: child),
      );

  Deck deckFor(String slug) => library.decks.firstWhere((d) => d.slug == slug);

  group('deck list', () {
    testWidgets('lists every bundled deck with its card count', (tester) async {
      await tester.pumpWidget(wrap(const DeckListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Goethe A1 Wordlist'), findsOneWidget);
      expect(find.text('1694 cards'), findsOneWidget);
    });

    testWidgets('a fresh install says nothing is scheduled, not nothing to do',
        (tester) async {
      await tester.pumpWidget(wrap(const DeckListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Nothing scheduled yet'), findsOneWidget);
      expect(find.textContaining('start learning new words'), findsOneWidget);
    });

    testWidgets('shows the streak and today count in the header', (tester) async {
      await tester.pumpWidget(wrap(const DeckListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('day streak'), findsOneWidget);
      expect(find.text('today'), findsOneWidget);
      expect(find.text('known'), findsWidgets);
    });

    testWidgets('every deck offers a Study action while cards remain',
        (tester) async {
      await tester.pumpWidget(wrap(const DeckListScreen()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Study'), findsWidgets);
    });
  });

  group('study session', () {
    Future<void> openStudy(WidgetTester tester, {int newLimit = 5}) async {
      await tester.pumpWidget(wrap(
        StudyScreen(deck: deckFor('goethe-a1'), newLimit: newLimit, reviewLimit: 50),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on a prompt with the answer hidden', (tester) async {
      await openStudy(tester);

      expect(find.text('Show answer'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Deutsch → English'), findsOneWidget);
      // None of the rating buttons are reachable before revealing.
      expect(find.text('Again'), findsNothing);
      expect(find.text('Easy'), findsNothing);
    });

    testWidgets('revealing shows the four rating buttons', (tester) async {
      await openStudy(tester);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      for (final label in ['Again', 'Hard', 'Good', 'Easy']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Show answer'), findsNothing);
    });

    testWidgets('revealing speaks the German side', (tester) async {
      await openStudy(tester);
      expect(tts.spokenText, isEmpty);

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      expect(tts.spokenText, hasLength(1),
          reason: 'the German word should be read out on reveal');
      expect(tts.spokenText.first, isNotEmpty);
    });

    testWidgets('speak on reveal can be switched off', (tester) async {
      await settings.setSpeakOnReveal(false);
      await openStudy(tester);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      expect(tts.spokenText, isEmpty);
    });

    testWidgets('answering advances to the next card', (tester) async {
      await openStudy(tester, newLimit: 3);
      expect(find.text('3 left'), findsOneWidget);

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();

      expect(find.text('2 left'), findsOneWidget);
      expect(find.text('Show answer'), findsOneWidget,
          reason: 'the next card starts face down');
    });

    testWidgets('tapping the card body also reveals it', (tester) async {
      await openStudy(tester);
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('Good'), findsOneWidget);
    });

    testWidgets('an undo action appears after the first answer', (tester) async {
      await openStudy(tester, newLimit: 3);
      expect(find.byIcon(Icons.undo), findsNothing);

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Good'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.undo), findsOneWidget);
    });

    testWidgets('undo returns to the previous card', (tester) async {
      await openStudy(tester, newLimit: 3);
      final first = tester.widget<Text>(
        find.descendant(
          of: find.byType(Column),
          matching: find.byType(Text),
        ).at(1),
      );

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Easy'));
      await tester.pumpAndSettle();
      expect(find.text('2 left'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      expect(find.text('3 left'), findsOneWidget);
      expect(find.text(first.data!), findsWidgets);
    });

    testWidgets('finishing the queue shows the session summary', (tester) async {
      await openStudy(tester, newLimit: 2);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Show answer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Easy'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Session complete'), findsOneWidget);
      expect(find.textContaining('2 answered'), findsOneWidget);
      expect(find.text('Easy: 2'), findsOneWidget);
      expect(find.text('Back to decks'), findsOneWidget);
    });

    testWidgets('a deck with no new cards allowed reports nothing due',
        (tester) async {
      await tester.pumpWidget(wrap(
        StudyScreen(deck: deckFor('goethe-a1'), newLimit: 0, reviewLimit: 50),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Nothing due in this deck'), findsOneWidget);
    });

    testWidgets('rating buttons carry their scheduling intervals', (tester) async {
      await openStudy(tester);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      // Good on a new card schedules the second learning step, 10 minutes out.
      expect(find.text('10m'), findsOneWidget);
      expect(find.text('4d'), findsOneWidget, reason: 'Easy graduates to 4 days');
    });

    testWidgets('intervals are hidden when the setting is off', (tester) async {
      await settings.setShowIntervals(false);
      await openStudy(tester);
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      expect(find.text('Good'), findsOneWidget);
      expect(find.text('10m'), findsNothing);
    });
  });

  group('search', () {
    testWidgets('finds a word and shows both sides', (tester) async {
      await tester.pumpWidget(wrap(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'Apotheke');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.textContaining('Apotheke'), findsWidgets);
    });

    testWidgets('folds umlauts so "uber" finds "über"', (tester) async {
      await tester.pumpWidget(wrap(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'uber');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('an unmatched query explains itself', (tester) async {
      await tester.pumpWidget(wrap(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'zzzzqqqq');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing matches'), findsOneWidget);
    });

    testWidgets('starts with a prompt rather than an empty list', (tester) async {
      await tester.pumpWidget(wrap(const SearchScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Look up any word'), findsOneWidget);
    });
  });

  group('speech service', () {
    test('picks the German locale out of the installed voices', () {
      expect(speech.status, SpeechStatus.ready);
      expect(speech.resolvedLocale, 'de-DE');
      expect(speech.canSpeak, isTrue);
    });

    test('reports a missing German voice rather than failing', () async {
      final fake = FakeTts(languages: const ['en-US', 'fr-FR'])..install();
      final service = SpeechService();
      await service.initialise();
      expect(service.status, SpeechStatus.missingGermanVoice);
      expect(service.canSpeak, isFalse);
      fake.remove();
    });

    test('plural markers and slashes are not read out literally', () async {
      tts.calls.clear();
      await speech.speak('die Ansage, -n');
      expect(tts.spokenText.single, 'die Ansage');

      tts.calls.clear();
      await speech.speak('break off / discontinue');
      expect(tts.spokenText.single, 'break off oder discontinue');
    });

    test('speaking is suppressed while disabled', () async {
      await speech.setEnabled(false);
      tts.calls.clear();
      await speech.speak('Guten Tag');
      expect(tts.spokenText, isEmpty);
    });
  });
}
