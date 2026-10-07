import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/widgets/learn_share_bar.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

/// learn-part-step-1 T9 (AC-01, AC-02, AC-03, AC-13): Learn on the Words screen.
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

void main() {
  late Session current;
  late Session past;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {String? shownId, Session? cur}) async {
    SharedPreferences.setMockInitialValues({});
    current = cur ??
        (Session.create()..words = [WordPair(word: 'coffee', translation: 'кава')]);
    past = Session.create()
      ..words = [
        WordPair(word: 'tea', translation: 'чай'),
        WordPair(word: 'milk', translation: 'молоко'),
        WordPair(word: 'bare'),
      ];
    container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeInput(current)),
      sessionByIdProvider(past.sessionId).overrideWith((ref) async => past),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(wordInputNotifierProvider.future);
      await container.read(sessionByIdProvider(past.sessionId).future);
    });
    final router = GoRouter(
      initialLocation:
          shownId == null ? '/table' : '/table?session-id=${past.sessionId}',
      routes: [
        GoRoute(
          path: '/table',
          builder: (context, state) => WordsTableScreen(
              sessionId: state.uri.queryParameters['session-id']),
          routes: [
            GoRoute(
              path: 'learn',
              builder: (context, state) => LearnScreen(
                  sessionId: state.uri.queryParameters['session-id']),
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
    await pump(tester, cur: Session.create());
    await tester.tap(learn);
    await tester.pump();
    expect(find.text('No words to learn'), findsOneWidget);
    expect(find.byType(LearnScreen), findsNothing);
    expect(find.byType(LearnShareBar), findsOneWidget);
  });

  testWidgets('Share still says "No words to share" when empty',
      (tester) async {
    await pump(tester, cur: Session.create());
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
        tester.widget<LearnScreen>(find.byType(LearnScreen)).sessionId, isNull);
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
    final beforeId = before.sessionId;
    final beforeWords = before.words.length;
    await tester.tap(learn);
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(tester.widget<LearnScreen>(find.byType(LearnScreen)).sessionId,
        past.sessionId);
    final after = container.read(wordInputNotifierProvider).value!;
    expect(after.sessionId, beforeId);
    expect(after.words.length, beforeWords);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WordsTableScreen), findsOneWidget);
  });
}
