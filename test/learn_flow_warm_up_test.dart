import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/learn_events_service.dart';
import 'package:flutter_vocabulary_app/core/services/learner_profile_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/talk_picture_service.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_words.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/grammar_rules.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/story_slots.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/warm_up_plan.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';

import 'fake_warm_up.dart';

/// learn-warm-up-v2 T10 (ADR-0002; AC-01–AC-08, AC-13, AC-17): the LearnFlow
/// notifier walks the warm-up plan: it saves each answer before its reaction,
/// starts the topic pick after the main answer, counts the warm-up when the
/// cards open, sends the fixed events and passes the grammar rule on.

final _now = DateTime(2026, 10, 31, 10);

class _OtherCurrent extends WordsNotifier {
  @override
  Future<WordCollection> build() async => WordCollection.create()..collectionId = 'other';
}

class _Store implements CollectionStore {
  _Store(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection?> byId(String collectionId) async => collectionId == collection.collectionId ? collection : null;

  @override
  Future<bool> update(String collectionId, void Function(WordCollection) change) async {
    change(collection);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected ${i.memberName}');
}

class _Runs implements StoryRunStore {
  @override
  Future<List<StoryRun>> newestFirst() async => [];

  @override
  Stream<StoryRun?> watch(String runId) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected ${i.memberName}');
}

class _Tracker extends StoryRunTracker {
  @override
  StoryTrackerState build() => const StoryTrackerState();

  @override
  StoryFollow follow() => StoryFollow.forTest(() {});

  @override
  Future<String?> startFor(String collectionId, WordGroup group,
          {bool replacing = false, List<Map<String, String>>? extras}) async =>
      null;
}

class _Picture extends TalkPictureService {
  @override
  Future<Uint8List?> draw(String prompt) => Completer<Uint8List?>().future;
}

class _Flow {
  _Flow(this.container, this.profile, this.reactions, this.events, this.topics, this.log);
  final ProviderContainer container;
  final FakeProfileStore profile;
  final FakeReactions reactions;
  final FakeEvents events;
  final FakeTopics topics;
  final List<String> log;

  LearnFlow get notifier => container.read(learnFlowProvider('c1').notifier);
  LearnFlowState get state => container.read(learnFlowProvider('c1'));
  Future<void> settle() => pumpEventQueue();

  /// Rates every card and skips the stories still waiting.
  Future<void> toDialog() async {
    for (var i = 0; i < state.words.length; i++) {
      await notifier.rate(SelfRating.easy);
    }
    await settle();
    while (state.phase == FlowPhase.cards) {
      final slot = state.slot;
      if (slot is WaitSlot) {
        notifier.skipStory(slot.story);
      } else if (slot is StorySlot) {
        notifier.storyDone();
      } else {
        break;
      }
    }
    expect(state.phase, FlowPhase.dialog);
  }
}

Future<_Flow> _flow(LearnerProfile profile, {bool limitToday = false}) async {
  final log = <String>[];
  final store = FakeProfileStore(profile, log);
  final reactions = FakeReactions(log);
  final events = FakeEvents();
  final topics = FakeTopics(log);
  final c = ProviderContainer(overrides: [
    wordsProvider.overrideWith(_OtherCurrent.new),
    collectionStoreProvider.overrideWith((ref) async => _Store(WordCollection.create()
      ..collectionId = 'c1'
      ..words = [for (var i = 0; i < 6; i++) WordPair(word: 'word$i', translation: 'слово$i', rowId: 'r$i')])),
    storyRunStoreProvider.overrideWith((ref) async => _Runs()),
    storyRunTrackerProvider.overrideWith(_Tracker.new),
    talkPictureServiceProvider.overrideWithValue(_Picture()),
    learnTopicsServiceProvider.overrideWithValue(topics),
    learnerProfileStoreProvider.overrideWithValue(store),
    warmUpReactionServiceProvider.overrideWithValue(reactions),
    learnEventsServiceProvider.overrideWithValue(events),
    learnFlowClockProvider.overrideWithValue(() => _now),
    learnFlowRandomProvider.overrideWithValue(Random(7)),
  ]);
  addTearDown(c.dispose);
  if (limitToday) c.read(talkLimitDayProvider.notifier).reached(_now);
  c.listen(learnFlowProvider('c1'), (_, __) {});
  await pumpEventQueue();
  return _Flow(c, store, reactions, events, topics, log);
}

const _goalFirst = ['goal', 'mood', 'daily'];

void main() {
  test('AC-01: no level → the intro comes first; a tap saves the level, then the reaction, then the main question',
      () async {
    final f = await _flow(const LearnerProfile(round: _goalFirst));
    expect(f.state.phase, FlowPhase.warmUp);
    expect(f.state.plan!.steps, [WarmUpStep.intro, WarmUpStep.main, WarmUpStep.topic, WarmUpStep.hardEasy]);
    expect(f.state.warmUpStep, WarmUpStep.intro);
    f.reactions.hold = true;
    f.notifier.answerLevel('Elementary');
    await f.settle();
    expect(f.log.where((l) => !l.startsWith('setRound')), ['setLevel:Elementary', 'react:intro'],
        reason: 'saved before the reaction');
    expect(f.state.warmUpStep, WarmUpStep.intro, reason: 'the next step waits for the reaction');
    expect(f.state.reacting, isTrue);
    f.reactions.release('Great level!');
    await f.settle();
    expect(f.state.reactions[WarmUpStep.intro], 'Great level!');
    expect(f.state.warmUpStep, WarmUpStep.main);
    expect(f.state.mainQuestion, MainQuestion.goal);
    expect(f.state.reacting, isFalse);
  });

  test('AC-02: a level (even Not sure) skips the intro; intro and grammar never in one warm-up', () async {
    final f = await _flow(const LearnerProfile(level: 'Not sure', round: _goalFirst));
    expect(f.state.plan!.steps, [WarmUpStep.main, WarmUpStep.topic, WarmUpStep.hardEasy]);
    final g = await _flow(const LearnerProfile(round: _goalFirst, grammarCounter: 6));
    expect(g.state.plan!.steps.contains(WarmUpStep.grammar), isFalse);
    expect(g.state.plan!.steps.first, WarmUpStep.intro);
  });

  test('AC-03: the round is saved at start; the main question leaves it only when answered', () async {
    final f = await _flow(const LearnerProfile(level: 'Intermediate', round: _goalFirst));
    expect(f.log, ['setRound:goal,mood,daily']);
    f.notifier.leave();
    await f.settle();
    expect(f.profile.profile.round.first, 'goal', reason: 'left unanswered, it stays first');

    final g = await _flow(const LearnerProfile(level: 'Intermediate', round: _goalFirst));
    g.notifier.answerMain('Travel confidently');
    await g.settle();
    expect(g.profile.profile.round, ['mood', 'daily']);
  });

  test('AC-04: own words: blank or over 80 is refused with nothing saved; a short answer goes to the store rule',
      () async {
    final f = await _flow(const LearnerProfile(level: 'Elementary', round: _goalFirst, goal: 'Make friends'));
    expect(f.notifier.answerMain('   ', own: true), isFalse);
    expect(f.notifier.answerMain('x' * 81, own: true), isFalse);
    await f.settle();
    expect(f.reactions.asked, isEmpty);
    expect(f.state.warmUpStep, WarmUpStep.main);
    expect(f.notifier.answerMain(' ok ', own: true), isTrue);
    await f.settle();
    expect(f.log, contains('saveGoalAnswer: ok '));
    expect(f.profile.profile.goal, 'Make friends', reason: 'a 1-2 character answer never replaces one');
    expect(f.reactions.asked.single, ('goal', ' ok '));
  });

  test('AC-05 / AC-13: the main answer is saved, the round marked, the pick started, then the reaction', () async {
    final f = await _flow(const LearnerProfile(level: 'Elementary', round: ['daily', 'goal', 'mood']));
    f.notifier.answerMain('Studying');
    await f.settle();
    expect(f.log.skip(1), ['setDaily:Studying', 'markMainAnswered:daily', 'topics.start', 'react:daily']);
    expect(f.topics.starts.single, {'level': 'Elementary', 'goal': null, 'daily': 'Studying', 'mood': null});
  });

  test('AC-06 / AC-13: mood is never saved; it goes to the pick as its id; topics land on the topic step', () async {
    final f = await _flow(const LearnerProfile(level: 'Advanced', round: ['mood', 'goal', 'daily']));
    expect(f.state.topics, isNull);
    expect(f.topics.starts, isEmpty, reason: 'the pick starts only after the main answer');
    f.notifier.answerMain('A little mystery');
    await f.settle();
    expect(f.log.where((l) => l.startsWith('set') && !l.startsWith('setRound')), isEmpty);
    expect(f.topics.starts.single['mood'], 'mystery');
    expect(f.state.warmUpStep, WarmUpStep.topic);
    expect(f.state.topics, fakeTopics);
  });

  test('AC-07: grammar due → 4 rules of the level; a rule goes to the dialog; the counter resets on cards open',
      () async {
    final f = await _flow(const LearnerProfile(level: 'Intermediate', round: _goalFirst, grammarCounter: 4));
    expect(f.state.plan!.steps, [WarmUpStep.main, WarmUpStep.grammar, WarmUpStep.topic, WarmUpStep.hardEasy]);
    f.notifier.answerMain('Make friends');
    await f.settle();
    expect(f.state.warmUpStep, WarmUpStep.grammar);
    expect(f.state.grammarRules.length, 4);
    expect(grammarRulesIntermediate, containsAll(f.state.grammarRules));
    final rule = f.state.grammarRules[1];
    f.notifier.answerGrammar(rule);
    await f.settle();
    expect(f.reactions.asked.last, ('grammar', rule));
    expect(f.state.grammarRule, rule);
    expect(f.log, isNot(contains(startsWith('setGrammarCounter'))), reason: 'counted only when the cards open');
    f.notifier.chooseTopic(fakeTopics.first);
    f.notifier.chooseMode(FlowMode.easy);
    await f.settle();
    expect(f.state.phase, FlowPhase.cards);
    expect(f.log, contains('setGrammarCounter:0'));
    await f.toDialog();
    expect(f.state.dialogSetup!.grammarRule, rule);
    expect(f.reactions.asked.length, 2, reason: 'at most 2 reactions');
    expect(f.topics.starts.length, 1, reason: 'one topic pick');
  });

  test('AC-10: the dialog\'s right / wrong counts and the rule reach the results; word results unchanged', () async {
    final f = await _flow(const LearnerProfile(level: 'Intermediate', round: _goalFirst, grammarCounter: 4));
    f.notifier.answerMain('Make friends');
    await f.settle();
    final rule = f.state.grammarRules.first;
    f.notifier.answerGrammar(rule);
    await f.settle();
    f.notifier.chooseTopic(fakeTopics.first);
    f.notifier.chooseMode(FlowMode.easy);
    await f.settle();
    await f.toDialog();
    f.notifier.recordDialog({'r0': DialogWordResult.used}, grammarRight: 3, grammarWrong: 1);
    final r = f.state.results!;
    expect(r.grammarRule, rule);
    expect((r.grammarRight, r.grammarWrong), (3, 1));
    expect(r.talk[DialogWordResult.used], 1);

    final g = await _flow(const LearnerProfile(level: 'Beginner', round: _goalFirst, grammarCounter: 2));
    g.notifier.answerMain('Make friends');
    await g.settle();
    g.notifier.chooseTopic(fakeTopics.first);
    g.notifier.chooseMode(FlowMode.easy);
    await g.settle();
    await g.toDialog();
    g.notifier.recordDialog({'r0': DialogWordResult.used});
    final none = g.state.results!;
    expect(none.grammarRule, isNull);
    expect((none.grammarRight, none.grammarWrong), (0, 0));
  });

  test('AC-07: "No, just talk" also resets the counter; no grammar step adds one', () async {
    final f = await _flow(const LearnerProfile(level: 'Beginner', round: _goalFirst, grammarCounter: 5));
    f.notifier.answerMain('Make friends');
    await f.settle();
    expect(grammarRulesElementary, containsAll(f.state.grammarRules));
    f.notifier.answerGrammar(null);
    await f.settle();
    expect(f.reactions.asked.last, ('grammar', 'No, just talk'));
    f.notifier.chooseTopic(fakeTopics.first);
    f.notifier.chooseMode(FlowMode.hard);
    await f.settle();
    expect(f.log, contains('setGrammarCounter:0'));
    expect(f.state.grammarRule, isNull);

    final g = await _flow(const LearnerProfile(level: 'Beginner', round: _goalFirst, grammarCounter: 2));
    g.notifier.answerMain('Make friends');
    await g.settle();
    g.notifier.chooseTopic(fakeTopics.first);
    g.notifier.chooseMode(FlowMode.hard);
    await g.settle();
    expect(g.log, contains('setGrammarCounter:3'));
  });

  test('AC-07: leaving at the grammar step keeps the counter', () async {
    final f = await _flow(const LearnerProfile(level: 'Intermediate', round: _goalFirst, grammarCounter: 4));
    f.notifier.answerMain('Make friends');
    await f.settle();
    f.notifier.leave();
    await f.settle();
    expect(f.log, isNot(contains(startsWith('setGrammarCounter'))));
    expect(f.profile.profile.grammarCounter, 4);
  });

  test('AC-08: talk limit reached today → no grammar step, and it stays due', () async {
    final f = await _flow(const LearnerProfile(level: 'Intermediate', round: _goalFirst, grammarCounter: 4),
        limitToday: true);
    expect(f.state.plan!.steps.contains(WarmUpStep.grammar), isFalse);
    f.notifier.answerMain('Make friends');
    await f.settle();
    f.notifier.chooseTopic(fakeTopics.first);
    f.notifier.chooseMode(FlowMode.easy);
    await f.settle();
    expect(f.log, contains('setGrammarCounter:5'));
  });

  test('AC-08: a refused main dialog marks the talk limit for today', () async {
    final f = await _flow(const LearnerProfile(level: 'Intermediate', round: _goalFirst));
    f.notifier.answerMain('Make friends');
    await f.settle();
    f.notifier.chooseTopic(fakeTopics.first);
    f.notifier.chooseMode(FlowMode.easy);
    await f.settle();
    await f.toDialog();
    f.notifier.dialogRefused();
    expect(f.container.read(talkLimitDayProvider), DateTime(2026, 10, 31));
  });

  test('AC-17: finishing sends shown, answered, grammar, topic and finished events with fixed values', () async {
    final f = await _flow(const LearnerProfile(level: 'Intermediate', round: _goalFirst, grammarCounter: 4));
    f.notifier.answerMain('Make friends');
    await f.settle();
    f.notifier.answerGrammar(f.state.grammarRules.first);
    await f.settle();
    f.notifier.ownTopic('My cat');
    f.notifier.chooseMode(FlowMode.easy);
    await f.settle();
    expect(f.events.all, [
      const LearnEvent.warmUpShown('goal'),
      const LearnEvent.warmUpAnswered('goal'),
      const LearnEvent.warmUpShown('grammar'),
      const LearnEvent.warmUpAnswered('grammar'),
      const LearnEvent.warmUpShown('topic'),
      const LearnEvent.warmUpAnswered('topic'),
      const LearnEvent.warmUpShown('difficulty'),
      const LearnEvent.warmUpAnswered('difficulty'),
      const LearnEvent.grammarAnswer(rule: true),
      const LearnEvent.topicPicked(own: true),
      const LearnEvent.warmUpFinished(4),
    ]);
    expect(f.events.all.every((e) => e.isValid), isTrue);
    f.notifier.leave();
    await f.settle();
    expect(f.events.batches.length, 1, reason: 'leaving after the cards opened sends no warm-up event');
  });

  test('AC-17: leaving the warm-up sends where it was left', () async {
    final f = await _flow(const LearnerProfile(round: _goalFirst));
    f.notifier.answerLevel('Advanced');
    await f.settle();
    f.notifier.leave();
    await f.settle();
    expect(f.events.all, [
      const LearnEvent.warmUpShown('intro'),
      const LearnEvent.warmUpAnswered('intro'),
      const LearnEvent.warmUpShown('goal'),
      const LearnEvent.warmUpLeft('goal'),
    ]);
  });

  test('topic and Hard/Easy answers wait for their step; they get no reaction', () async {
    final f = await _flow(const LearnerProfile(level: 'Elementary', round: _goalFirst));
    f.notifier.chooseTopic(fakeTopics.first);
    f.notifier.chooseMode(FlowMode.easy);
    await f.settle();
    expect(f.state.topic, isNull);
    expect(f.state.phase, FlowPhase.warmUp);
    f.notifier.answerMain('Make friends');
    await f.settle();
    f.notifier.chooseTopic(fakeTopics[2]);
    await f.settle();
    expect(f.state.warmUpStep, WarmUpStep.hardEasy);
    f.notifier.chooseMode(FlowMode.easy);
    await f.settle();
    expect(f.state.phase, FlowPhase.cards);
    expect(f.reactions.asked.length, 1);
    expect(dialogReplies(FlowMode.easy), 6);
  });
}
