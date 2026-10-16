import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/widgets/learn_share_bar.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

/// learn-part-step-1 T9 (AC-01, AC-02, AC-03, AC-13): Learn on the Words screen.
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

void main() {
  late WordCollection current;
  late WordCollection past;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {String? shownId, WordCollection? cur}) async {
    SharedPreferences.setMockInitialValues({});
    current = cur ??
        (WordCollection.create()..words = [WordPair(word: 'coffee', translation: 'кава')]);
    past = WordCollection.create()
      ..words = [
        WordPair(word: 'tea', translation: 'чай'),
        WordPair(word: 'milk', translation: 'молоко'),
        WordPair(word: 'bare'),
      ];
    container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeInput(current)),
      collectionByIdProvider(past.collectionId).overrideWith((ref) async => past),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(wordInputNotifierProvider.future);
      await container.read(collectionByIdProvider(past.collectionId).future);
    });
    final router = GoRouter(
      initialLocation:
          shownId == null ? '/table' : '/table?collection-id=${past.collectionId}',
      routes: [
        GoRoute(
          path: '/table',
          builder: (context, state) => WordsTableScreen(
              collectionId: state.uri.queryParameters['collection-id']),
          routes: [
            GoRoute(
              path: 'learn',
              builder: (context, state) => LearnScreen(
                  collectionId: state.uri.queryParameters['collection-id']),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  final learn = find.text('Learn');

  testWidgets('the AppBar is the LearnShareBar', (tester) async {
    await pump(tester);
    expect(find.byType(LearnShareBar), findsOneWidget);
    expect(find.text('Words'), findsOneWidget);
  });

  testWidgets('AC-03: empty session shows the SnackBar and stays',
      (tester) async {
    await pump(tester, cur: WordCollection.create());
    await tester.tap(learn);
    await tester.pump();
    expect(find.text('No words to learn'), findsOneWidget);
    expect(find.byType(LearnScreen), findsNothing);
    expect(find.byType(LearnShareBar), findsOneWidget);
  });

  testWidgets('Share still says "No words to share" when empty',
      (tester) async {
    await pump(tester, cur: WordCollection.create());
    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(find.text('No words to share'), findsOneWidget);
  });

  testWidgets('AC-02: current session opens learn, back returns',
      (tester) async {
    await pump(tester);
    await tester.tap(learn);
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(
        tester.widget<LearnScreen>(find.byType(LearnScreen)).collectionId, isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsNothing);
    expect(find.byType(WordsTableScreen), findsOneWidget);
    expect(find.byType(LearnShareBar), findsOneWidget);
  });

  testWidgets('AC-13: a History session opens learn for it, current untouched',
      (tester) async {
    await pump(tester, shownId: 'past');
    final before = container.read(wordInputNotifierProvider).value!;
    final beforeId = before.collectionId;
    final beforeWords = before.words.length;
    await tester.tap(learn);
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(tester.widget<LearnScreen>(find.byType(LearnScreen)).collectionId,
        past.collectionId);
    final after = container.read(wordInputNotifierProvider).value!;
    expect(after.collectionId, beforeId);
    expect(after.words.length, beforeWords);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WordsTableScreen), findsOneWidget);
  });
}
