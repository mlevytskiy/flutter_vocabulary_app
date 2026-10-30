import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_result.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_stories.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';
import 'package:flutter_vocabulary_app/features/learn/session/session_results_screen.dart';

/// learn-welcome T16 (AC-15): the flow's results on the session results
/// screen — Cards, Stories, Talk, due tomorrow, and the three buttons.

FlowStory _story(int i, {bool reused = false}) =>
    FlowStory(index: i, groupId: 'g$i', rowIds: ['r$i'], reused: reused, status: FlowStoryStatus.ready);

LearnFlowResults _results({bool talkLimit = false, int saved = 1}) => LearnFlowResults(
      ratingCounts: const {
        SelfRating.dontRemember: 3,
        SelfRating.hard: 5,
        SelfRating.medium: 7,
        SelfRating.easy: 11,
      },
      movedUp: const ['a', 'b'],
      movedDown: const ['c'],
      storiesShown: [_story(0), _story(1, reused: true)],
      storiesSaved: [for (var i = 0; i < saved; i++) _story(2 + i)],
      talk: const {
        DialogWordResult.used: 4,
        DialogWordResult.afterHint: 2,
        DialogWordResult.missed: 1,
        DialogWordResult.unused: 6,
      },
      talkLimit: talkLimit,
      dueTomorrow: 9,
    );

void main() {
  Future<List<String>> pump(WidgetTester tester, LearnFlowResults results) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final visited = <String>[];
    final flow = FlowResult(collectionId: 'c1', results: results, cardRowIds: const ['r1', 'r2', 'r3']);
    Widget landing(String name) => Builder(builder: (context) {
          visited.add(GoRouterState.of(context).uri.toString());
          return Text(name);
        });
    final router = GoRouter(initialLocation: '/words', routes: [
      GoRoute(
        path: '/words',
        builder: (context, _) => TextButton(onPressed: () => context.push('/flow'), child: const Text('words')),
        routes: [
          GoRoute(path: 'table/session', builder: (_, __) => landing('session')),
          GoRoute(path: 'table/talk', builder: (_, __) => landing('talk')),
        ],
      ),
      GoRoute(path: '/flow', builder: (_, __) => SessionResultsScreen(flow: flow)),
    ]);
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.tap(find.text('words'));
    await tester.pumpAndSettle();
    return visited;
  }

  testWidgets('cards, stories, talk and due tomorrow', (tester) async {
    await pump(tester, _results());
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text("3\nI don't remember"), findsOneWidget);
    expect(find.text('5\nHard'), findsOneWidget);
    expect(find.text('7\nMedium'), findsOneWidget);
    expect(find.text('11\nEasy'), findsOneWidget);
    expect(find.text('2 words moved up · 1 moved down'), findsOneWidget);

    expect(find.text('Stories'), findsOneWidget);
    expect(find.byKey(const ValueKey('flow-story-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('flow-story-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('flow-story-2')), findsNothing);
    expect(find.text('Story saved to Story runs'), findsOneWidget);

    expect(find.text('Talk'), findsOneWidget);
    expect(find.text('4\nused'), findsOneWidget);
    expect(find.text('2\nafter hint'), findsOneWidget);
    expect(find.text('1\nmissed'), findsOneWidget);
    expect(find.text('6\nunused'), findsOneWidget);
    expect(find.text(SessionResultsScreen.talkLimitText), findsNothing);

    expect(find.text('9 words due tomorrow'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Talk with AI'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('talk limit and several saved stories', (tester) async {
    await pump(tester, _results(talkLimit: true, saved: 2));
    expect(find.text(SessionResultsScreen.talkLimitText), findsOneWidget);
    expect(find.text('4\nused'), findsNothing);
    expect(find.text('2 stories saved to Story runs'), findsOneWidget);
  });

  testWidgets('Exercises opens a session on the card words', (tester) async {
    final visited = await pump(tester, _results());
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    expect(find.text('session'), findsOneWidget);
    final uri = Uri.parse(visited.single);
    expect(uri.queryParameters['collection-id'], 'c1');
    expect(uri.queryParameters['row-ids'], 'r1,r2,r3');
    expect(uri.queryParameters['split'], 'false');
  });

  testWidgets('Talk with AI opens a talk', (tester) async {
    final visited = await pump(tester, _results());
    await tester.tap(find.text('Talk with AI'));
    await tester.pumpAndSettle();
    expect(find.text('talk'), findsOneWidget);
    expect(Uri.parse(visited.single).queryParameters['collection-id'], 'c1');
  });

  testWidgets('Done goes back to Words', (tester) async {
    await pump(tester, _results());
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('words'), findsOneWidget);
  });

  test('FlowResult.of is null before the results, then carries the card row ids', () {
    expect(FlowResult.of('c1', const LearnFlowState()), isNull);
    final state = LearnFlowState(
      words: [WordPair(word: 'a', translation: 'x', rowId: 'r1'), WordPair(word: 'b', translation: 'y', rowId: 'r2')],
      results: _results(),
    );
    final flow = FlowResult.of('c1', state)!;
    expect(flow.cardRowIds, ['r1', 'r2']);
    expect(flow.collectionId, 'c1');
  });
}
