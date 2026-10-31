import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learner_profile_store.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/warm_up_plan.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/warm_up_view.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_widgets.dart';

import 'fake_warm_up.dart';
import 'learn_session_talk_voice_test.dart' show FakeSpeech;

/// learn-warm-up-v2 T11 (AC-01, AC-03, AC-04, AC-06, AC-07, AC-13): the
/// warm-up dialog over a hand-walked flow.
const _id = 'c1';

final _words = [
  for (var i = 0; i < 9; i++) WordPair(word: 'word$i', translation: 't$i', rowId: 'r$i'),
];

const _rules = ['Present Perfect', 'Past Continuous', 'First conditional', 'Modal verbs for advice'];

LearnFlowState _state(List<WarmUpStep> steps,
        {MainQuestion main = MainQuestion.goal,
        int stepIndex = 0,
        Map<WarmUpStep, String> answers = const {},
        Map<WarmUpStep, String> reactions = const {},
        List<String> grammarRules = const []}) =>
    LearnFlowState(
      phase: FlowPhase.warmUp,
      words: _words,
      plan: WarmUpPlan(steps: steps, main: main, round: [main.name]),
      stepIndex: stepIndex,
      answers: answers,
      reactions: reactions,
      grammarRules: grammarRules,
    );

const _firstTime = [WarmUpStep.intro, WarmUpStep.main, WarmUpStep.topic, WarmUpStep.hardEasy];
const _plain = [WarmUpStep.main, WarmUpStep.topic, WarmUpStep.hardEasy];
const _grammar = [WarmUpStep.main, WarmUpStep.grammar, WarmUpStep.topic, WarmUpStep.hardEasy];

void main() {
  late FakeWarmUpFlow flow;
  late FakeSpeech speech;

  Future<void> pump(WidgetTester t, LearnFlowState initial, {bool hold = false}) async {
    flow = FakeWarmUpFlow(initial)..hold = hold;
    speech = FakeSpeech();
    t.view.physicalSize = const Size(430, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(initialLocation: '/flow', routes: [
      GoRoute(
        path: '/flow',
        builder: (context, _) => Scaffold(
          appBar: WarmUpView.appBar(context, collectionId: _id),
          body: const WarmUpView(collectionId: _id),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(ProviderScope(
      overrides: [
        learnFlowProvider(_id).overrideWith(() => flow),
        speechInputProvider.overrideWithValue(speech),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
  }

  Finder text(String s) => find.textContaining(s, findRichText: true);
  Finder exact(String s) => find.text(s, findRichText: true);
  Future<void> tap(WidgetTester t, String s) async {
    await t.tap(exact(s).last);
    await t.pumpAndSettle();
  }

  double bar(WidgetTester t, int i) => t.widget<LinearProgressIndicator>(find.byKey(warmUpStepKey(i))).value!;
  IconButton send(WidgetTester t) => t.widget<IconButton>(find.byKey(warmUpSendKey));

  testWidgets('AC-01 / AC-06: first time — a 4-step bar, the level question with six taps, the gear, no Skip',
      (t) async {
    await pump(t, _state(_firstTime));
    for (var i = 1; i <= 4; i++) {
      expect(bar(t, i), i == 1 ? 1 : 0);
    }
    expect(find.byKey(warmUpStepKey(5)), findsNothing);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(text(warmUpLevelQuestion), findsOneWidget);
    expect(find.byType(TalkChoiceButton), findsNWidgets(learnerLevels.length));
    for (final level in learnerLevels) {
      expect(text(level), findsOneWidget);
    }
    expect(find.byKey(warmUpSettingsKey), findsOneWidget);
    expect(text('Skip'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('AC-01: a level tap is answered, the reaction shows, then the main question on step 2', (t) async {
    await pump(t, _state(_firstTime), hold: true);
    await tap(t, 'Intermediate');
    expect(flow.calls, ['level:Intermediate']);
    expect(find.byKey(warmUpReactingKey), findsOneWidget, reason: 'waiting for the reaction');
    expect(text(warmUpMainQuestions[MainQuestion.goal]!), findsNothing);
    expect(find.byType(TalkChoiceButton), findsNothing, reason: 'the level taps are gone');

    flow.react();
    await t.pumpAndSettle();
    expect(find.byKey(warmUpReactingKey), findsNothing);
    expect(text('Intermediate'), findsOneWidget, reason: 'the answer stays as my bubble');
    expect(text('Nice one!'), findsOneWidget);
    expect(text(warmUpMainQuestions[MainQuestion.goal]!), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(bar(t, 2), 1);
    expect(bar(t, 3), 0);
  });

  for (final main in MainQuestion.values) {
    testWidgets('AC-03 / AC-06: the ${main.name} question on a 3-step bar with its taps', (t) async {
      await pump(t, _state(_plain, main: main));
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.byKey(warmUpStepKey(4)), findsNothing);
      expect(text(warmUpMainQuestions[main]!), findsOneWidget);
      final taps = switch (main) {
        MainQuestion.mood => moodChoices.keys.toList(),
        MainQuestion.goal => [...goalChoices, warmUpSomethingElse],
        MainQuestion.daily => [...dailyChoices, warmUpSomethingElse],
      };
      expect(find.byType(TalkChoiceButton), findsNWidgets(taps.length));
      for (final c in taps) {
        expect(exact(c), findsOneWidget);
      }
      final first = taps.first;
      await tap(t, first);
      expect(flow.calls, ['main:$first']);
      expect(text('Nice one!'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget, reason: 'the real flow moves past the main question');
    });
  }

  testWidgets('AC-03: the mood question has no Something else', (t) async {
    await pump(t, _state(_plain, main: MainQuestion.mood));
    expect(text(warmUpSomethingElse), findsNothing);
  });

  testWidgets('AC-04: Something else — Send disabled for blank and over 80 (trimmed), the warning, then sent',
      (t) async {
    await pump(t, _state(_plain, main: MainQuestion.goal));
    expect(find.byKey(warmUpOwnTopicFieldKey), findsNothing);
    await tap(t, warmUpSomethingElse);
    expect(find.byKey(warmUpOwnTopicFieldKey), findsOneWidget);
    expect(find.byKey(warmUpMicKey), findsOneWidget);
    expect(send(t).onPressed, isNull, reason: 'empty');
    await t.enterText(find.byKey(warmUpOwnTopicFieldKey), '   ');
    await t.pump();
    expect(send(t).onPressed, isNull, reason: 'blank');
    await t.enterText(find.byKey(warmUpOwnTopicFieldKey), 'a' * 81);
    await t.pump();
    expect(send(t).onPressed, isNull, reason: 'over 80 characters');
    expect(find.text(warmUpTooLong), findsOneWidget);
    await t.enterText(find.byKey(warmUpOwnTopicFieldKey), '  ${'a' * 80}  ');
    await t.pump();
    expect(send(t).onPressed, isNotNull, reason: '80 characters once trimmed');
    expect(find.text(warmUpTooLong), findsNothing);
    await t.enterText(find.byKey(warmUpOwnTopicFieldKey), ' Cook for my kids ');
    await t.pump();
    await t.tap(find.byKey(warmUpSendKey));
    await t.pumpAndSettle();
    expect(flow.calls, ['main: Cook for my kids  (own)']);
    expect(find.byKey(warmUpOwnTopicFieldKey), findsNothing, reason: 'the composer closes');
    expect(text('Cook for my kids'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('AC-04: spoken own words follow the same rule as typed', (t) async {
    await pump(t, _state(_plain, main: MainQuestion.daily));
    await tap(t, warmUpSomethingElse);
    await t.tap(find.byKey(warmUpMicKey));
    await t.pump();
    expect(speech.listening, isTrue);
    speech.heard('b' * 81);
    await t.pump();
    expect(send(t).onPressed, isNull);
    expect(find.text(warmUpTooLong), findsOneWidget);
    speech.heard('I look after my garden');
    await t.pump();
    await t.tap(find.byKey(warmUpMicKey));
    await t.pump();
    await t.tap(find.byKey(warmUpSendKey));
    await t.pumpAndSettle();
    expect(flow.calls, ['main:I look after my garden (own)']);
  });

  testWidgets('AC-07: the grammar question with its 4 rules and No, just talk', (t) async {
    await pump(
        t,
        _state(_grammar,
            stepIndex: 1,
            answers: {WarmUpStep.main: 'Make friends'},
            reactions: {WarmUpStep.main: 'Lovely!'},
            grammarRules: _rules));
    expect(find.text('2 / 4'), findsOneWidget);
    expect(text('Make friends'), findsOneWidget);
    expect(text('Lovely!'), findsOneWidget);
    expect(text(warmUpGrammarQuestion), findsOneWidget);
    expect(find.byType(TalkChoiceButton), findsNWidgets(5));
    for (final r in [..._rules, noGrammarAnswer]) {
      expect(text(r), findsOneWidget);
    }
    expect(text(warmUpSomethingElse), findsNothing, reason: 'taps only');
    await tap(t, noGrammarAnswer);
    expect(flow.calls, ['grammar:null']);
    expect(find.text('3 / 4'), findsOneWidget);
  });

  testWidgets('AC-07: a rule tap sends the rule', (t) async {
    await pump(t, _state(_grammar, stepIndex: 1, answers: {WarmUpStep.main: 'Working'}, grammarRules: _rules));
    await tap(t, 'Past Continuous');
    expect(flow.calls, ['grammar:Past Continuous']);
  });

  testWidgets('AC-13: topic tiles show their situation lines and My own topic…; then Hard / Easy', (t) async {
    await pump(t, _state(_plain, main: MainQuestion.mood));
    await tap(t, 'A little mystery');
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byType(TalkChoiceButton), findsNWidgets(4));
    for (final topic in fakeTopics) {
      expect(text(topic.title), findsOneWidget);
      expect(find.text(topic.situation), findsOneWidget);
    }
    expect(text(warmUpOwnTopicChoice), findsOneWidget);
    await tap(t, 'Trip');
    expect(flow.calls.last, 'topic:t2');
    expect(find.text('3 / 3'), findsOneWidget);
    expect(text(warmUpModeQuestion), findsOneWidget);
    await tap(t, warmUpHardChoice);
    expect(flow.calls.last, 'mode:hard');
    expect(text('Skip'), findsNothing);
  });

  testWidgets('AC-13: while the topics load a waiting bubble shows', (t) async {
    await pump(t, _state(_plain, stepIndex: 1, answers: {WarmUpStep.main: 'Working'}));
    expect(find.byKey(warmUpTopicsLoadingKey), findsOneWidget);
    expect(find.byType(TalkChoiceButton), findsNothing);
  });
}
