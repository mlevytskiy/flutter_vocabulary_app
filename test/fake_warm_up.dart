import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/services/learn_events_service.dart';
import 'package:flutter_vocabulary_app/core/services/learn_topics_service.dart';
import 'package:flutter_vocabulary_app/core/services/learner_profile_store.dart';
import 'package:flutter_vocabulary_app/core/services/warm_up_reaction_service.dart';

/// Fakes for the learn-warm-up-v2 services the Learn flow calls. They share
/// one [log] so tests can check the order of saves, picks and reactions.

/// The learner profile in memory.
class FakeProfileStore extends LearnerProfileStore {
  FakeProfileStore(this.profile, this.log);
  LearnerProfile profile;
  final List<String> log;

  @override
  Future<LearnerProfile> read() async => profile;

  @override
  Future<void> setLevel(String? level) async {
    log.add('setLevel:$level');
    profile = profile.copyWith(level: () => level);
  }

  @override
  Future<void> setGoal(String? goal) async {
    log.add('setGoal:$goal');
    profile = profile.copyWith(goal: () => goal);
  }

  @override
  Future<void> setDaily(String? daily) async {
    log.add('setDaily:$daily');
    profile = profile.copyWith(daily: () => daily);
  }

  @override
  Future<void> saveGoalAnswer(String text) async {
    log.add('saveGoalAnswer:$text');
    final t = text.trim();
    if (t.length > 2 || profile.goal == null) profile = profile.copyWith(goal: () => t);
  }

  @override
  Future<void> saveDailyAnswer(String text) async {
    log.add('saveDailyAnswer:$text');
    final t = text.trim();
    if (t.length > 2 || profile.daily == null) profile = profile.copyWith(daily: () => t);
  }

  @override
  Future<void> setRound(List<String> round) async {
    log.add('setRound:${round.join(',')}');
    profile = profile.copyWith(round: List.of(round));
  }

  @override
  Future<void> markMainAnswered(String id) async {
    log.add('markMainAnswered:$id');
    profile = profile.copyWith(round: profile.round.where((q) => q != id).toList());
  }

  @override
  Future<void> setGrammarCounter(int n) async {
    log.add('setGrammarCounter:$n');
    profile = profile.copyWith(grammarCounter: n);
  }

  @override
  Future<void> setTalksCounter(int n) async {
    log.add('setTalksCounter:$n');
    profile = profile.copyWith(talksCounter: n);
  }
}

/// Reactions: 'Nice one!' at once, or held until [release] when [hold].
class FakeReactions extends WarmUpReactionService {
  FakeReactions(this.log);
  final List<String> log;
  final asked = <(String, String)>[];
  bool hold = false;
  Completer<String>? _held;

  void release([String line = 'Nice one!']) => _held?.complete(line);

  @override
  Future<String> react(String question, String answer) {
    log.add('react:$question');
    asked.add((question, answer));
    if (!hold) return Future.value('Nice one!');
    return (_held = Completer<String>()).future;
  }
}

/// Events: every batch sent.
class FakeEvents extends LearnEventsService {
  final batches = <List<LearnEvent>>[];

  List<LearnEvent> get all => [for (final b in batches) ...b];

  @override
  Future<void> send(List<LearnEvent> events) async => batches.add(events);
}

/// Three topics with situation lines over a stubbed Worker.
const fakeTopics = [
  LearnTopic(id: 't1', title: 'Cafe', description: 'd1', situation: 's1'),
  LearnTopic(id: 't2', title: 'Trip', description: 'd2', situation: 's2'),
  LearnTopic(id: 't3', title: 'Work', description: 'd3', situation: 's3'),
];

/// The topic pick: [starts] holds each start's profile and mood.
class FakeTopics extends LearnTopicsService {
  FakeTopics(this.log)
      : super(
            client: MockClient((_) async => http.Response(
                jsonEncode({
                  'topics': [
                    for (final t in fakeTopics)
                      {'id': t.id, 'title': t.title, 'description': t.description, 'situation': t.situation},
                  ]
                }),
                200)));
  final List<String> log;
  final starts = <Map<String, String?>>[];
  final picks = <List<String>>[];

  @override
  PendingTopics start(List<String> words, {String? level, String? goal, String? daily, String? mood}) {
    log.add('topics.start');
    starts.add({'level': level, 'goal': goal, 'daily': daily, 'mood': mood});
    return super.start(words, level: level, goal: goal, daily: daily, mood: mood);
  }

  @override
  Future<List<LearnTopic>> pick(List<String> words, {String? level, String? goal, String? daily, String? mood}) {
    picks.add(words);
    return super.pick(words, level: level, goal: goal, daily: daily, mood: mood);
  }
}
