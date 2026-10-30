import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/learn_presets.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/learn_settings_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';
import 'fake_story_groups.dart';

/// learn-redesign T15 (AC-17, AC-18, AC-19): the Learn settings screen.
class _Fake extends WordsNotifier {
  _Fake(this.c);
  final WordCollection c;
  @override
  Future<WordCollection> build() async => c;
}

void main() {
  late ProviderContainer container;
  final collection = WordCollection.create()
    ..words = [
      for (var i = 0; i < 5; i++)
        WordPair(word: 'word$i', translation: 'слово$i')..rowId = 'r$i',
    ];

  Future<GoRouter> pump(WidgetTester tester, {required String initial}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    container = ProviderContainer(overrides: [
      ...fakeGroupOverrides(),
      wordsProvider.overrideWith(() => _Fake(collection)),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(learnSettingsProvider.notifier).loaded;
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(wordsProvider.future);
    });
    final router = GoRouter(initialLocation: initial, routes: [
      GoRoute(
        path: '/words/table',
        builder: (_, __) => const WordsTableScreen(),
        routes: [
          GoRoute(
            path: 'learn-settings',
            builder: (_, s) => LearnSettingsScreen(
                collectionId: s.uri.queryParameters['collection-id']),
          ),
          GoRoute(
            path: 'learn',
            builder: (_, s) => LearnScreen(
              collectionId: s.uri.queryParameters['collection-id'],
              initialExercise: s.uri.queryParameters['exercise'],
            ),
          ),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  final settingsAt = const LearnSettingsRoute().location;

  Finder switchOf(String name) => find.descendant(
      of: find.widgetWithText(ListTile, name), matching: find.byType(Switch));

  bool on(WidgetTester t, String name) =>
      t.widget<Switch>(switchOf(name)).value;

  LearnPreset picked() => container.read(learnSettingsProvider).preset;

  testWidgets('AC-17: Balanced is picked by default, with subtitles',
      (t) async {
    await pump(t, initial: settingsAt);
    expect(find.text('Learn settings'), findsOneWidget);
    expect(picked(), LearnPreset.balanced);
    expect(
        t
            .widget<RadioGroup<LearnPreset>>(
                find.byType(RadioGroup<LearnPreset>))
            .groupValue,
        LearnPreset.balanced);
    expect(find.text('about 5 min, one-word answers only'), findsOneWidget);
    expect(find.text('Step 1 · Meet'), findsOneWidget);
    expect(find.text('Step 2 · Practise'), findsOneWidget);
    expect(find.text('Step 3 · Use'), findsOneWidget);
    expect(on(t, 'Match synonyms'), isTrue);
    expect(on(t, 'Explain it to a friend'), isFalse);
  });

  testWidgets('AC-17: picking Quick sets its switches', (t) async {
    await pump(t, initial: settingsAt);
    await t.tap(find.text('Quick'));
    await t.pumpAndSettle();
    expect(picked(), LearnPreset.quick);
    expect(on(t, 'Guess my word'), isFalse);
    expect(on(t, 'Quiz'), isTrue);
  });

  testWidgets('AC-17: a switch change moves the preset to Custom', (t) async {
    await pump(t, initial: settingsAt);
    await t.tap(switchOf('Guess my word'));
    await t.pumpAndSettle();
    expect(picked(), LearnPreset.custom);
    expect(on(t, 'Guess my word'), isFalse);
    await t.tap(switchOf('Guess my word'));
    await t.pumpAndSettle();
    expect(picked(), LearnPreset.balanced);
  });

  testWidgets('AC-18: the last exercise of a step cannot be turned off',
      (t) async {
    await pump(t, initial: settingsAt);
    // Step 2 in Balanced: fill-the-gaps, remember-or-not, sentence-patterns.
    for (final n in ['Fill the gaps', 'Remember or not']) {
      await t.tap(switchOf(n));
      await t.pumpAndSettle();
    }
    await t.tap(switchOf('Sentence patterns'));
    await t.pump();
    expect(find.text('Each step needs at least one exercise'), findsOneWidget);
    expect(on(t, 'Sentence patterns'), isTrue);
  });

  testWidgets('AC-17: words per session is remembered', (t) async {
    await pump(t, initial: settingsAt);
    expect(find.text("Used when the words aren't split into groups"),
        findsOneWidget);
    await t.tap(find.byType(DropdownButton<WordsPerSession>));
    await t.pumpAndSettle();
    await t.tap(find.text('20').last);
    await t.pumpAndSettle();
    expect(container.read(learnSettingsProvider).wordsPerSession,
        WordsPerSession.twenty);
  });

  testWidgets('AC-19: story and dialogue rows have Try it and no switch',
      (t) async {
    await pump(t, initial: settingsAt);
    for (final n in ['Mnemonic story', 'Dialogs from movie']) {
      final row = find.widgetWithText(ListTile, n);
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.byType(Switch)),
          findsNothing);
      expect(find.descendant(of: row, matching: find.text('Try it')),
          findsOneWidget);
    }
    expect(find.text('Try it'), findsNWidgets(13));
    // The eleven session pages, plus Hands-free talk (AC-29).
    expect(find.byType(Switch), findsNWidgets(12));
  });

  testWidgets('AC-19: Try it opens the Learn page with that exercise ticked',
      (t) async {
    await pump(t, initial: settingsAt);
    expect(const LearnRoute(collectionId: 'c', exercise: 'match-synonyms').location,
        '/words/table/learn?collection-id=c&exercise=match-synonyms');
    await t.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'Match synonyms'),
        matching: find.text('Try it')));
    await t.pumpAndSettle();
    final tile = t.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Match synonyms'));
    expect(tile.value, isTrue);
    expect(find.text('Pick at least one exercise'), findsNothing);
  });

}
