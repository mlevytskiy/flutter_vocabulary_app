import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/theme/app_theme.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_stories.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/story_page.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/story_slots.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';

/// A flow whose state the test sets; it records the calls.
class _FakeFlow extends LearnFlow {
  _FakeFlow(this.initial);

  final LearnFlowState initial;
  final calls = <String>[];

  @override
  LearnFlowState build(String collectionId) => initial;

  void push(LearnFlowState next) => state = next;

  @override
  Future<void> rate(SelfRating rating) async => calls.add('rate:${rating.name}');

  @override
  void storyDone() => calls.add('storyDone');

  @override
  void skipStory(int story) => calls.add('skip:$story');

  @override
  void leave() => calls.add('leave');
}

final words = [
  for (final (w, t) in [
    ('apple', 'яблуко'),
    ('river', 'річка'),
    ('stone', 'камінь'),
    ('cloud', 'хмара'),
    ('bread', 'хліб')
  ])
    WordPair(word: w, translation: t, rowId: 'r-$w'),
];

LearnFlowState cards({int done = 0, NextSlot slot = const CardSlot(), List<FlowStory>? stories}) => LearnFlowState(
      phase: FlowPhase.cards,
      words: words,
      cardsDone: done,
      slot: slot,
      stories: stories ??
          [
            const FlowStory(
                index: 0, groupId: 'g0', rowIds: ['r-apple'], status: FlowStoryStatus.writing, progress: 0.4)
          ],
    );

late _FakeFlow fake;

Future<void> open(WidgetTester tester, LearnFlowState initial,
    {Map<FlowPhase, FlowPhaseBuilder> phases = const {}, bool settle = true}) async {
  fake = _FakeFlow(initial);
  await tester.pumpWidget(ProviderScope(
    overrides: [learnFlowProvider.overrideWith(() => fake)],
    child: MaterialApp(
      theme: appThemes.first.build(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(PageRouteBuilder<void>(
                  pageBuilder: (_, __, ___) => LearnFlowScreen(collectionId: 'c1', phases: phases))),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> flipAndRate(WidgetTester tester, SelfRating rating) async {
  await tester.tap(find.byKey(const ValueKey('self-check-card')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('rate-${rating.name}')));
  await tester.pump();
}

void main() {
  testWidgets('card page: "Card N of M" and the front; rating calls rate', (tester) async {
    await open(tester, cards());
    expect(find.text('Card 1 of 5'), findsOneWidget);
    expect(find.text('яблуко'), findsOneWidget);
    await flipAndRate(tester, SelfRating.easy);
    expect(fake.calls, ['rate:easy']);

    fake.push(cards(done: 1));
    await tester.pumpAndSettle();
    expect(find.text('Card 2 of 5'), findsOneWidget);
    expect(find.text('річка'), findsOneWidget);
    expect(find.text('Card 1 of 5'), findsNothing);
  });

  testWidgets('story page after its card: the picture alone; a tap moves on', (tester) async {
    await open(tester, cards());
    const ready = FlowStory(
        index: 0,
        groupId: 'g0',
        rowIds: ['r-apple'],
        status: FlowStoryStatus.ready,
        picturePath: '/no/such.png',
        progress: 1);
    fake.push(cards(done: 1, slot: const StorySlot(0), stories: const [ready]));
    await tester.pumpAndSettle();
    expect(find.byType(StoryPage), findsOneWidget);
    expect(find.textContaining('Card'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    await tester.tap(find.byKey(const ValueKey('flow-story-page')));
    expect(fake.calls, ['storyDone']);
    // Once only.
    await tester.tap(find.byKey(const ValueKey('flow-story-page')));
    expect(fake.calls, ['storyDone']);
  });

  testWidgets('the pager keeps its page when the screen turns (T14)', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    await open(tester, cards());
    fake.push(cards(done: 1, slot: const StorySlot(0)));
    await tester.pumpAndSettle();
    expect(find.byType(StoryPage), findsOneWidget);
    final before = tester.widget<PageView>(find.byType(PageView)).controller!.page;
    tester.view.physicalSize = const Size(1600, 800);
    await tester.pumpAndSettle();
    expect(find.byType(StoryPage), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, before);
    expect(before, 1);
  });

  testWidgets('a swipe on the story page moves on too', (tester) async {
    await open(tester, cards(slot: const StorySlot(0)));
    await tester.drag(find.byKey(const ValueKey('flow-story-page')), const Offset(-300, 0));
    expect(fake.calls, ['storyDone']);
  });

  testWidgets('wait page: progress and Skip; it turns into the story when ready', (tester) async {
    await open(tester, cards(done: 1, slot: const WaitSlot(0)));
    expect(find.text('Writing your story…'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('flow-wait-progress')));
    expect(bar.value, 0.4);
    await tester.tap(find.text('Skip, show it later'));
    expect(fake.calls, ['skip:0']);

    // More progress.
    fake.push(cards(done: 1, slot: const WaitSlot(0), stories: const [
      FlowStory(index: 0, groupId: 'g0', rowIds: ['r-apple'], status: FlowStoryStatus.writing, progress: 0.7),
    ]));
    await tester.pump();
    expect(tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('flow-wait-progress'))).value, 0.7);

    // Ready: the notifier opens the story by itself.
    fake.push(cards(done: 1, slot: const StorySlot(0), stories: const [
      FlowStory(
          index: 0,
          groupId: 'g0',
          rowIds: ['r-apple'],
          status: FlowStoryStatus.ready,
          picturePath: '/x.png',
          progress: 1),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Writing your story…'), findsNothing);
    expect(find.byType(StoryPage), findsOneWidget);
  });

  testWidgets('close asks with the leave dialog; Stay keeps, Leave calls leave and pops', (tester) async {
    await open(tester, cards());
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Leave the session? Progress in this session is lost.'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 5'), findsOneWidget);
    expect(fake.calls, isEmpty);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['leave']);
    expect(find.byType(LearnFlowScreen), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('system Back on a card asks too', (tester) async {
    await open(tester, cards());
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Leave the session? Progress in this session is lost.'), findsOneWidget);
  });

  testWidgets('other phases show their builder, else a placeholder', (tester) async {
    await open(tester, const LearnFlowState(),
        phases: {
          FlowPhase.warmUp: (context, s, flow) => Text('warm-up ${s.words.length}'),
        },
        settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    fake.push(LearnFlowState(phase: FlowPhase.warmUp, words: words));
    await tester.pump();
    expect(find.text('warm-up 5'), findsOneWidget);
    fake.push(cards());
    await tester.pumpAndSettle();
    expect(find.text('Card 1 of 5'), findsOneWidget);
  });
}
