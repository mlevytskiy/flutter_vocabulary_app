import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_page.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/warm_up_view.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';
import 'package:flutter_vocabulary_app/features/learn/session/session_results_screen.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

import 'learn_session_talk_voice_test.dart' show FakeSpeech;

/// learn-welcome T17 (AC-01, AC-17): Learn on the Words screen opens the
/// Learn flow; the Learn sheet, its split checkbox and group line are gone.
class _FakeWords extends WordsNotifier {
  _FakeWords(this.c);
  final WordCollection c;
  @override
  Future<WordCollection> build() async => c;
}

class _FakeFlow extends LearnFlow {
  _FakeFlow(this.initial);
  final LearnFlowState initial;
  @override
  LearnFlowState build(String collectionId) => initial;
  void push(LearnFlowState next) => state = next;
}

WordCollection _collection(int n) => WordCollection.create()
  ..words = [
    for (var i = 0; i < n; i++) WordPair(word: 'word$i', translation: 'слово$i')..rowId = 'r$i',
  ];

void main() {
  group('Learn on the Words screen', () {
    late ProviderContainer container;
    late WordCollection current;
    late WordCollection past;
    late List<String> flowUris;

    Future<void> pump(WidgetTester t, int n, {bool showPast = false}) async {
      SharedPreferences.setMockInitialValues({});
      current = _collection(n);
      past = _collection(6);
      flowUris = [];
      container = ProviderContainer(overrides: [
        wordsProvider.overrideWith(() => _FakeWords(current)),
        collectionByIdProvider(past.collectionId).overrideWith((ref) async => past),
      ]);
      addTearDown(container.dispose);
      await t.runAsync(() async {
        await container.read(wordDetailModeProvider.notifier).loaded;
        await container.read(wordsProvider.future);
        await container.read(collectionByIdProvider(past.collectionId).future);
      });
      final router = GoRouter(
        initialLocation: showPast ? '/words/table?collection-id=${past.collectionId}' : '/words/table',
        routes: [
          GoRoute(
            path: '/words/table',
            builder: (_, s) => WordsTableScreen(collectionId: s.uri.queryParameters['collection-id']),
            routes: [
              GoRoute(
                path: 'flow',
                builder: (_, s) {
                  flowUris.add(s.uri.toString());
                  return const Scaffold(body: Text('flow screen'));
                },
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('AC-01: Learn opens the flow of the current collection, no sheet', (t) async {
      await pump(t, 5);
      await t.tap(find.text('Learn'));
      await t.pumpAndSettle();
      expect(find.text('flow screen'), findsOneWidget);
      expect(Uri.parse(flowUris.last).queryParameters['collection-id'], current.collectionId);
      expect(find.text('How do you want to learn?'), findsNothing);
      expect(find.text('Split words into groups of 7–12'), findsNothing);
    });

    testWidgets('AC-01: exactly 4 words opens the flow', (t) async {
      await pump(t, 4);
      await t.tap(find.text('Learn'));
      await t.pumpAndSettle();
      expect(find.text('flow screen'), findsOneWidget);
    });

    testWidgets('AC-01: fewer than 4 words shows the snackbar and opens nothing', (t) async {
      await pump(t, 3);
      await t.tap(find.text('Learn'));
      await t.pump();
      expect(find.text(flowTooFewWordsMessage), findsOneWidget);
      expect(flowUris, isEmpty);
      expect(find.text('How do you want to learn?'), findsNothing);
      await t.pumpAndSettle();
      expect(find.text('flow screen'), findsNothing);
    });

    testWidgets('AC-01: an empty collection shows the same snackbar', (t) async {
      await pump(t, 0);
      await t.tap(find.text('Learn'));
      await t.pump();
      expect(find.text(flowTooFewWordsMessage), findsOneWidget);
      expect(flowUris, isEmpty);
    });

    testWidgets('a shown History collection opens its own flow', (t) async {
      await pump(t, 5, showPast: true);
      await t.tap(find.text('Learn'));
      await t.pumpAndSettle();
      expect(Uri.parse(flowUris.last).queryParameters['collection-id'], past.collectionId);
    });

    testWidgets('companion menu: alone ticked, teacher/friend Soon', (t) async {
      await pump(t, 5);
      await t.tap(find.byTooltip('Learn with'));
      await t.pumpAndSettle();
      expect(find.text('Learn alone'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('Soon'), findsNWidgets(2));
      final teacher = t.widget<PopupMenuItem<String>>(find.widgetWithText(PopupMenuItem<String>, 'With teacher'));
      final friend = t.widget<PopupMenuItem<String>>(find.widgetWithText(PopupMenuItem<String>, 'With friend'));
      expect(teacher.enabled, isFalse);
      expect(friend.enabled, isFalse);
      await t.tap(find.text('Learn alone'));
      await t.pumpAndSettle();
      expect(find.text('Learn alone'), findsNothing);
      expect(find.text('flow screen'), findsNothing);
    });
  });

  group('LearnFlowPage', () {
    const id = 'c1';
    late _FakeFlow flow;

    Future<void> pump(WidgetTester t, LearnFlowState initial) async {
      t.view.physicalSize = const Size(800, 1600);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      flow = _FakeFlow(initial);
      final router = GoRouter(initialLocation: '/words/table', routes: [
        GoRoute(
          path: '/words/table',
          builder: (context, _) => Scaffold(
            body: TextButton(onPressed: () => context.push('/words/table/flow'), child: const Text('table')),
          ),
          routes: [
            GoRoute(path: 'flow', builder: (_, __) => const LearnFlowPage(collectionId: id)),
            GoRoute(
              path: 'talk',
              builder: (context, s) => Scaffold(
                body: Column(children: [
                  Text('talk ${s.uri.queryParameters['learn-flow']} ${s.uri.queryParameters['collection-id']}'),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('end talk')),
                ]),
              ),
            ),
          ],
        ),
      ]);
      addTearDown(router.dispose);
      await t.pumpWidget(ProviderScope(
        overrides: [
          learnFlowProvider(id).overrideWith(() => flow),
          speechInputProvider.overrideWithValue(FakeSpeech()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('table'));
      await t.pumpAndSettle();
    }

    testWidgets('the warm-up with the gear to Learn settings', (t) async {
      await pump(t, const LearnFlowState(phase: FlowPhase.warmUp, topics: []));
      expect(find.byType(WarmUpView), findsOneWidget);
      expect(find.byKey(warmUpSettingsKey), findsOneWidget);
    });

    testWidgets('the dialog pushes Talk once; its end shows the results', (t) async {
      await pump(t, const LearnFlowState(phase: FlowPhase.dialog));
      expect(find.text('talk true c1'), findsOneWidget);
      // Talk hands its result to the flow first, then pops (talk_notifier
      // _finishFlow), so the flow is at its results when Talk closes.
      flow.push(const LearnFlowState(
        phase: FlowPhase.results,
        results: LearnFlowResults(
          ratingCounts: {
            SelfRating.dontRemember: 0,
            SelfRating.hard: 0,
            SelfRating.medium: 0,
            SelfRating.easy: 1,
          },
          movedUp: [],
          movedDown: [],
          storiesShown: [],
          storiesSaved: [],
          talk: {},
          talkLimit: false,
          dueTomorrow: 0,
        ),
      ));
      await t.pump();
      await t.tap(find.text('end talk'));
      await t.pumpAndSettle();
      expect(find.textContaining('talk '), findsNothing, reason: 'Talk is pushed only once');
      expect(find.byType(SessionResultsScreen), findsOneWidget);
      expect(find.text('Cards'), findsOneWidget);
    });

    testWidgets('refused: the snackbar, then back', (t) async {
      await pump(t, const LearnFlowState(phase: FlowPhase.refused));
      expect(find.text(flowTooFewWordsMessage), findsOneWidget);
      expect(find.text('table'), findsOneWidget);
    });
  });
}
