import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

/// learn-redesign T14 (AC-01, AC-03, AC-04, AC-05, AC-06, AC-14, AC-27).
class _Fake extends WordsNotifier {
  _Fake(this.c);
  final WordCollection c;
  @override
  Future<WordCollection> build() async => c;
}

WordCollection _collection(int n) => WordCollection.create()
  ..words = [
    for (var i = 0; i < n; i++)
      WordPair(word: 'word$i', translation: 'слово$i')..rowId = 'r$i',
  ];

void main() {
  late ProviderContainer container;
  late WordCollection c;
  String? sessionUri;

  Future<void> pump(WidgetTester tester, int n) async {
    SharedPreferences.setMockInitialValues({});
    c = _collection(n);
    sessionUri = null;
    container = ProviderContainer(overrides: [
      wordsNotifierProvider.overrideWith(() => _Fake(c)),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(wordsNotifierProvider.future);
    });
    final router = GoRouter(initialLocation: '/words/table', routes: [
      GoRoute(
        path: '/words/table',
        builder: (_, __) => const WordsTableScreen(),
        routes: [
          GoRoute(
            path: 'session',
            builder: (_, state) {
              sessionUri = state.uri.toString();
              return const Scaffold(body: Text('session screen'));
            },
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
  }

  testWidgets('AC-03: no words to learn shows the SnackBar, no sheet',
      (t) async {
    await pump(t, 0);
    await t.tap(find.text('Learn'));
    await t.pump();
    expect(find.text('Add words with a translation to start learning'),
        findsOneWidget);
    expect(find.text('How do you want to learn?'), findsNothing);
  });

  testWidgets('AC-01: Learn opens the sheet with counts; under 20 no split',
      (t) async {
    await pump(t, 5);
    await t.tap(find.text('Learn'));
    await t.pumpAndSettle();
    expect(find.text('How do you want to learn?'), findsOneWidget);
    expect(find.text('5 words · 0 due'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('3 steps · a mix of short tasks'), findsOneWidget);
    expect(find.text('Talk with AI'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byTooltip('Learn settings'), findsOneWidget);
    await t.tap(find.text('Talk with AI'));
    await t.pumpAndSettle();
    expect(find.text('How do you want to learn?'), findsNothing);
  });

  testWidgets('AC-06: Exercises with under 20 words pushes split=false',
      (t) async {
    await pump(t, 5);
    await t.tap(find.text('Learn'));
    await t.pumpAndSettle();
    await t.tap(find.text('Exercises'));
    await t.pumpAndSettle();
    expect(find.text('session screen'), findsOneWidget);
    expect(sessionUri, contains('split=false'));
  });

  testWidgets('AC-05: from 20 words the split box is ticked, with next group',
      (t) async {
    await pump(t, 34);
    await t.tap(find.text('Learn'));
    await t.pumpAndSettle();
    final box = t.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(box.value, isTrue);
    expect(find.text('Split words into groups of 7–12'), findsOneWidget);
    expect(find.textContaining('Next: Group 1 of '), findsOneWidget);

    await t.tap(find.byType(CheckboxListTile));
    await t.pumpAndSettle();
    expect(container.read(learnSplitNotifierProvider(c.collectionId)), isFalse);
    expect(find.textContaining('Next: '), findsNothing);
    await t.tap(find.text('Exercises'));
    await t.pumpAndSettle();
    expect(sessionUri, contains('split=false'));
  });

  testWidgets('AC-05: split ticked is passed to the session route', (t) async {
    await pump(t, 34);
    await t.tap(find.text('Learn'));
    await t.pumpAndSettle();
    await t.tap(find.text('Exercises'));
    await t.pumpAndSettle();
    // split=true is the route's default, so it may be left out of the URL.
    expect(sessionUri, isNot(contains('split=false')));
  });

  testWidgets('AC-04: companion menu: alone ticked, teacher/friend Soon',
      (t) async {
    await pump(t, 5);
    expect(find.text('Learn'), findsOneWidget);
    await t.tap(find.byTooltip('Learn with'));
    await t.pumpAndSettle();
    expect(find.text('Learn alone'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Soon'), findsNWidgets(2));
    final teacher =
        t.widget<PopupMenuItem<String>>(find.widgetWithText(PopupMenuItem<String>, 'With teacher'));
    final friend =
        t.widget<PopupMenuItem<String>>(find.widgetWithText(PopupMenuItem<String>, 'With friend'));
    expect(teacher.enabled, isFalse);
    expect(friend.enabled, isFalse);
    await t.tap(find.text('Learn alone'));
    await t.pumpAndSettle();
    expect(find.text('Learn alone'), findsNothing);
    expect(find.text('How do you want to learn?'), findsNothing);
  });
}
