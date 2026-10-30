import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_topics_service.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_words.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/warm_up_view.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_widgets.dart';

import 'learn_session_talk_voice_test.dart' show FakeSpeech;

/// learn-welcome T12 (AC-02, AC-04): the warm-up view over a fake flow.
class _FakeFlow extends LearnFlow {
  _FakeFlow(this.initial);

  final LearnFlowState initial;
  final topicsChosen = <LearnTopic>[];
  final ownTopics = <String>[];
  final modes = <FlowMode>[];

  @override
  LearnFlowState build(String collectionId) => initial;

  void set(LearnFlowState next) => state = next;

  @override
  void chooseTopic(LearnTopic topic) {
    topicsChosen.add(topic);
    state = state.copyWith(topic: FlowTopic(id: topic.id, text: topic.title, description: topic.description));
  }

  @override
  bool ownTopic(String text) {
    ownTopics.add(text);
    if (text.trim().isEmpty || text.length > maxOwnTopicLength) return false;
    state = state.copyWith(topic: FlowTopic(text: text));
    return true;
  }

  @override
  void chooseMode(FlowMode mode) => modes.add(mode);
}

const _id = 'c1';

final _words = [
  for (var i = 0; i < 9; i++) WordPair(word: 'word$i', translation: 't$i', rowId: 'r$i'),
];

const _topics = [
  LearnTopic(id: 'travel', title: 'Travel', description: 'Trips and places.'),
  LearnTopic(id: 'food', title: 'Food and cooking', description: 'What you eat.'),
  LearnTopic(id: 'work', title: 'Work life', description: 'Your job.'),
];

LearnFlowState _warm({List<LearnTopic>? topics = _topics, FlowTopic? topic}) =>
    LearnFlowState(phase: FlowPhase.warmUp, words: _words, topics: topics, topic: topic);

void main() {
  late _FakeFlow flow;
  late FakeSpeech speech;

  Future<void> pump(WidgetTester t, LearnFlowState initial) async {
    flow = _FakeFlow(initial);
    speech = FakeSpeech();
    final router = GoRouter(initialLocation: '/words/table/flow', routes: [
      GoRoute(path: '/words/table', builder: (_, __) => const Scaffold(body: Text('table')), routes: [
        GoRoute(
          path: 'flow',
          builder: (context, _) => Scaffold(
            appBar: WarmUpView.appBar(context, collectionId: _id),
            body: const WarmUpView(collectionId: _id),
          ),
        ),
        GoRoute(
          path: 'learn-settings',
          builder: (_, s) => Scaffold(body: Text('settings ${s.uri.queryParameters['collection-id']}')),
        ),
      ]),
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

  double barValue(WidgetTester t, Key key) => t.widget<LinearProgressIndicator>(find.byKey(key)).value!;

  IconButton send(WidgetTester t) => t.widget<IconButton>(find.byKey(warmUpSendKey));

  testWidgets('AC-02: a 2-step bar on step 1, the AI question, 3 topics and My own topic…, no Skip', (t) async {
    await pump(t, _warm());
    expect(find.byKey(warmUpStepKey1), findsOneWidget);
    expect(find.byKey(warmUpStepKey2), findsOneWidget);
    expect(barValue(t, warmUpStepKey1), 1);
    expect(barValue(t, warmUpStepKey2), 0);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(TalkBubble), findsOneWidget);
    expect(find.textContaining('Hi! 9 words today. What would you like to talk about?', findRichText: true),
        findsOneWidget);
    expect(find.byType(TalkChoiceButton), findsNWidgets(4));
    for (final topic in _topics) {
      expect(find.textContaining(topic.title, findRichText: true), findsOneWidget);
      expect(find.text(topic.description), findsOneWidget);
    }
    expect(find.textContaining(warmUpOwnTopicChoice, findRichText: true), findsOneWidget);
    expect(find.textContaining('Skip', findRichText: true), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('AC-03: while the topics load a waiting bubble shows and no choices', (t) async {
    await pump(t, _warm(topics: null));
    expect(find.byKey(warmUpTopicsLoadingKey), findsOneWidget);
    expect(find.byType(TalkChoiceButton), findsNothing);
    flow.set(_warm());
    await t.pumpAndSettle();
    expect(find.byKey(warmUpTopicsLoadingKey), findsNothing);
    expect(find.byType(TalkChoiceButton), findsNWidgets(4));
  });

  testWidgets('the flow still loading shows the waiting bubble only', (t) async {
    await pump(t, const LearnFlowState());
    expect(find.byKey(warmUpTopicsLoadingKey), findsOneWidget);
    expect(find.textContaining('Hi!', findRichText: true), findsNothing);
  });

  testWidgets('AC-02: a tapped topic goes to chooseTopic, then Q2 asks Hard or Easy on step 2', (t) async {
    await pump(t, _warm());
    await t.tap(find.textContaining('Food and cooking', findRichText: true));
    await t.pumpAndSettle();
    expect(flow.topicsChosen, [_topics[1]]);
    expect(barValue(t, warmUpStepKey2), 1);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.textContaining(warmUpModeQuestion, findRichText: true), findsOneWidget);
    expect(find.textContaining(warmUpHardChoice, findRichText: true), findsOneWidget);
    expect(find.textContaining(warmUpEasyChoice, findRichText: true), findsOneWidget);
    expect(find.textContaining('Skip', findRichText: true), findsNothing);
  });

  testWidgets('AC-02: Hard and Easy call chooseMode', (t) async {
    await pump(t, _warm(topic: const FlowTopic(id: 'travel', text: 'Travel')));
    await t.tap(find.textContaining(warmUpHardChoice, findRichText: true));
    await t.pump();
    await t.tap(find.textContaining(warmUpEasyChoice, findRichText: true));
    await t.pump();
    expect(flow.modes, [FlowMode.hard, FlowMode.easy]);
  });

  testWidgets('AC-04: own topic — Send disabled while empty, over 80 refused, the text sent as it is', (t) async {
    await pump(t, _warm());
    expect(find.byKey(warmUpOwnTopicFieldKey), findsNothing);
    await t.tap(find.textContaining(warmUpOwnTopicChoice, findRichText: true));
    await t.pumpAndSettle();
    expect(find.byKey(warmUpOwnTopicFieldKey), findsOneWidget);
    expect(find.byKey(warmUpMicKey), findsOneWidget);
    expect(send(t).onPressed, isNull, reason: 'empty');
    await t.enterText(find.byKey(warmUpOwnTopicFieldKey), '   ');
    await t.pump();
    expect(send(t).onPressed, isNull, reason: 'blank');
    await t.enterText(find.byKey(warmUpOwnTopicFieldKey), 'a' * 81);
    await t.pump();
    expect(send(t).onPressed, isNull, reason: 'over 80 characters');
    await t.enterText(find.byKey(warmUpOwnTopicFieldKey), 'a' * 80);
    await t.pump();
    expect(send(t).onPressed, isNotNull, reason: '80 characters is allowed');
    await t.enterText(find.byKey(warmUpOwnTopicFieldKey), ' My trip to Lviv ');
    await t.pump();
    await t.tap(find.byKey(warmUpSendKey));
    await t.pumpAndSettle();
    expect(flow.ownTopics, [' My trip to Lviv ']);
    expect(find.textContaining(warmUpModeQuestion, findRichText: true), findsOneWidget);
    expect(find.byKey(warmUpOwnTopicFieldKey), findsNothing);
  });

  testWidgets('AC-04: the talk\'s mic dictates the own topic into the field', (t) async {
    await pump(t, _warm());
    await t.tap(find.textContaining(warmUpOwnTopicChoice, findRichText: true));
    await t.pumpAndSettle();
    expect(find.byType(TalkMicCircle), findsOneWidget);
    await t.tap(find.byKey(warmUpMicKey));
    await t.pump();
    expect(speech.inits, 1);
    expect(speech.listening, isTrue);
    speech.heard('cooking with friends');
    await t.pump();
    expect(find.text('cooking with friends'), findsOneWidget);
    await t.tap(find.byKey(warmUpMicKey));
    await t.pump();
    expect(speech.listening, isFalse);
    expect(send(t).onPressed, isNotNull);
    await t.tap(find.byKey(warmUpSendKey));
    await t.pumpAndSettle();
    expect(flow.ownTopics, ['cooking with friends']);
  });

  testWidgets('AC-02/AC-17: the gear opens Learn settings', (t) async {
    await pump(t, _warm());
    await t.tap(find.byKey(warmUpSettingsKey));
    await t.pumpAndSettle();
    expect(find.text('settings $_id'), findsOneWidget);
  });
}
