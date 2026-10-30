import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/talk_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_words.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/session/leitner.dart' show WordOutcome, intervalDays;
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';
import 'package:flutter_vocabulary_app/features/learn/session/session_result.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_quiz.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_screen.dart';

import 'learn_session_talk_test.dart' show FakeQuizData, FakeTalkApi, FakeTalkPicture;

/// A flow parked at its main dialog: hands [setup] to the talk and keeps what
/// the talk reports.
class _FakeFlow extends LearnFlow {
  _FakeFlow(this.setup);

  final LearnDialogSetup setup;
  Map<String, DialogWordResult>? recorded;
  int refused = 0;

  @override
  LearnFlowState build(String collectionId) => LearnFlowState(phase: FlowPhase.dialog, dialogSetup: setup);

  @override
  void recordDialog(Map<String, DialogWordResult> results) => recorded = results;

  @override
  void dialogRefused() => refused++;

  /// The picture drawn during the cards arrives.
  void drawn(Uint8List? bytes) => state = state.copyWith(dialogSetup: setup.withPicture(bytes, false));
}

/// learn-welcome T15 (AC-13, AC-14): the Talk notifier and screen in
/// learn-flow mode over a fake flow, a fake talk service and a temporary
/// store.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late CollectionStore store;
  late StoryRunStore runs;

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('learn_flow_talk_test');
    store = await CollectionStore.open(directory: dir.path);
    runs = await StoryRunStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final words = ['ticket', 'crowded', 'bus', 'table'];
  WordPair pair(int i) => WordPair(word: words[i], translation: 't-${words[i]}', rowId: 'r${i + 1}');
  final picture = Uint8List.fromList([1, 2, 3]);

  /// A collection with [words] (r1…r4); r1 sits in box 3.
  Future<String> newCollection() async {
    final c = await store.create(keep: true, name: 'Trip');
    c.words = [for (var i = 0; i < words.length; i++) pair(i)];
    await store.put(c);
    await store.update(c.collectionId, (c) {
      c.boxes = [
        WordBox()
          ..rowId = 'r1'
          ..word = 'ticket'
          ..box = 3
          ..dueAt = DateTime(2026, 10, 30)
          ..lastUpDay = '2026-10-25',
      ];
    });
    return c.collectionId;
  }

  /// The dialog setup over [order] (indexes into [words]).
  LearnDialogSetup setupOf(String id,
          {List<int> order = const [1, 0, 2, 3], int maxReplies = 6, Uint8List? bytes, bool loading = false}) =>
      LearnDialogSetup(
        collectionId: id,
        topic: const FlowTopic(id: 'travel', text: 'Travel', description: 'Trips and tickets'),
        mode: maxReplies == 6 ? FlowMode.easy : FlowMode.hard,
        maxReplies: maxReplies,
        words: [for (final i in order) pair(i)],
        picture: bytes,
        pictureLoading: loading,
      );

  ({ProviderContainer c, Talk talk, _FakeFlow flow, FakeTalkPicture pictures}) container(
      String id, FakeTalkApi api, LearnDialogSetup setup) {
    final flow = _FakeFlow(setup);
    final pictures = FakeTalkPicture()..bytes = Uint8List.fromList([9]);
    final c = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runs),
      talkApiServiceProvider.overrideWithValue(api),
      talkPictureServiceProvider.overrideWithValue(pictures),
      learnApiServiceProvider.overrideWithValue(FakeQuizData()),
      learnFlowProvider(id).overrideWith(() => flow),
    ]);
    addTearDown(c.dispose);
    c.listen(learnFlowProvider(id), (_, __) {}, fireImmediately: true);
    c.listen(talkProvider(id, learnFlow: true), (_, __) {}, fireImmediately: true);
    return (c: c, talk: c.read(talkProvider(id, learnFlow: true).notifier), flow: flow, pictures: pictures);
  }

  const mission = TalkMission(
    title: 'Catch the bus',
    role: 'You are a traveller',
    goal: 'Get a ticket',
    brief: 'The driver is grumpy',
    words: ['crowded'],
    picture: 'a bus stop',
  );

  test('sends the flow\'s words in order, the topic and the reply limit; no second picture', () async {
    final id = await newCollection();
    final api = FakeTalkApi()..answers.add(const TalkTurn(reply: 'Hi!', target: 'crowded', mission: mission));
    final (:c, :talk, :flow, :pictures) = container(id, api, setupOf(id, bytes: picture));
    await talk.startFlow();
    final start = api.calls.single;
    expect(start.kind, 'start');
    expect([for (final w in start.words) w.word], ['crowded', 'ticket', 'bus', 'table']);
    expect(start.target, 'crowded');
    expect(api.flows.single.topic, (id: 'travel', text: 'Travel'));
    expect(api.flows.single.maxReplies, 6);
    final s = c.read(talkProvider(id, learnFlow: true));
    // Every chosen word stays, even when the mission names fewer.
    expect(s.words.length, 4);
    expect(s.picture, picture);
    expect(s.pictureLoading, isFalse);
    expect(s.replyLimit, 6);
    expect(s.mission, isNotNull);
    expect(pictures.prompts, isEmpty);
    await talk.send('hello');
    expect(api.calls.last.kind, 'reply');
    expect(api.flows.last.topic, (id: 'travel', text: 'Travel'));
    expect(api.flows.last.maxReplies, 6);
    expect(flow.recorded, isNull);
  });

  test('a picture still drawing shows as loading, then arrives from the flow', () async {
    final id = await newCollection();
    final api = FakeTalkApi()..answers.add(const TalkTurn(reply: 'Hi!', target: 'crowded', mission: mission));
    final (:c, :talk, :flow, :pictures) = container(id, api, setupOf(id, loading: true));
    await talk.startFlow();
    expect(c.read(talkProvider(id, learnFlow: true)).pictureLoading, isTrue);
    flow.drawn(picture);
    await Future<void>.delayed(Duration.zero);
    final s = c.read(talkProvider(id, learnFlow: true));
    expect(s.pictureLoading, isFalse);
    expect(s.picture, picture);
    expect(pictures.prompts, isEmpty);
  });

  test('ends at the reply limit whatever the AI said', () async {
    final id = await newCollection();
    final api = FakeTalkApi();
    for (var i = 0; i < 7; i++) {
      api.answers
          .add(const TalkTurn(reply: 'Pick one', target: 'crowded', interaction: 'choice', choices: ['Yes', 'No']));
    }
    final (:c, :talk, flow: _, pictures: _) = container(id, api, setupOf(id));
    await talk.startFlow();
    for (var i = 0; i < 5; i++) {
      await talk.send('Yes', isChoice: true);
      expect(c.read(talkProvider(id, learnFlow: true)).complete, isFalse);
    }
    await talk.send('Yes', isChoice: true);
    final s = c.read(talkProvider(id, learnFlow: true));
    expect(s.repliesCount, 6);
    expect(s.complete, isTrue);
    expect(s.choices, isEmpty);
  });

  test('the end records used / after hint / unused per word and moves no box (AC-14)', () async {
    final id = await newCollection();
    final before = (await store.byId(id))!;
    final boxesBefore = [for (final b in before.boxes) (b.rowId, b.box, b.dueAt, b.lastUpDay)];
    final api = FakeTalkApi()..answers.add(const TalkTurn(reply: 'Hi!', target: 'crowded'));
    final (:c, :talk, :flow, pictures: _) = container(id, api, setupOf(id));
    await talk.startFlow();
    talk.showHint();
    api.answers.add(const TalkTurn(reply: 'Nice.', target: 'ticket', interaction: 'complete'));
    await talk.send('The crowded bus');
    await talk.finish();
    expect(flow.recorded, {
      'r2': DialogWordResult.afterHint,
      'r1': DialogWordResult.unused,
      'r3': DialogWordResult.used,
      'r4': DialogWordResult.unused,
    });
    final after = (await store.byId(id))!;
    expect([for (final b in after.boxes) (b.rowId, b.box, b.dueAt, b.lastUpDay)], boxesBefore);
    final results = {for (final r in after.results) r.rowId: r};
    expect(results.keys.toSet(), {'r2', 'r3'});
    expect(results['r3']!.label, WordResultLabel.known);
    expect(results['r2']!.label, WordResultLabel.repeat);
    expect(results['r3']!.exerciseId, talkExerciseId);
    expect(c.read(lastSessionResultProvider), isNull);
    expect(c.read(talkProvider(id, learnFlow: true)).status, TalkStatus.over);
  });

  test('a missed word\'s self-check rating moves its box at once; the dialog result is still recorded', () async {
    // self-check-cards AC-11, learn-welcome AC-14 / ADR-0004.
    final quizWords = ['shore', 'tide', 'fog', 'gale', 'harbour'];
    WordPair q(int i) => WordPair(word: quizWords[i], translation: 't-${quizWords[i]}', rowId: 'q${i + 1}');
    final col = await store.create(keep: true, name: 'Sea');
    col.words = [for (var i = 0; i < quizWords.length; i++) q(i)];
    await store.put(col);
    final id = col.collectionId;
    await store.update(id, (c) {
      c.boxes = [
        WordBox()
          ..rowId = 'q1'
          ..word = 'shore'
          ..box = 3
          ..dueAt = DateTime(2026, 10, 30)
          ..lastUpDay = '2026-10-25',
      ];
    });
    final setup = LearnDialogSetup(
      collectionId: id,
      topic: const FlowTopic(id: 'sea', text: 'Sea', description: ''),
      mode: FlowMode.easy,
      maxReplies: 6,
      words: [for (var i = 0; i < quizWords.length; i++) q(i)],
    );
    final flow = _FakeFlow(setup);
    final api = FakeTalkApi()
      ..answers
          .add(const TalkTurn(reply: 'The fog hides the shore, the tide, a gale and the harbour.', target: 'shore'));
    final c = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runs),
      talkApiServiceProvider.overrideWithValue(api),
      talkPictureServiceProvider.overrideWithValue(FakeTalkPicture()),
      learnApiServiceProvider.overrideWithValue(FakeQuizData()),
      learnFlowProvider(id).overrideWith(() => flow),
      learnFlowClockProvider.overrideWithValue(() => DateTime(2026, 10, 30, 10)),
    ]);
    addTearDown(c.dispose);
    c.listen(learnFlowProvider(id), (_, __) {}, fireImmediately: true);
    c.listen(talkProvider(id, learnFlow: true), (_, __) {}, fireImmediately: true);
    final talk = c.read(talkProvider(id, learnFlow: true).notifier);
    await talk.startFlow();
    await pumpEventQueue();
    TalkQuizItem current() => c.read(talkProvider(id, learnFlow: true)).openQuiz!.quiz!.current;
    talk.answerQuiz('wave'); // wrong: shore
    talk.nextQuiz();
    talk.answerQuiz('tide');
    talk.nextQuiz();
    talk.answerQuiz('fog');
    talk.nextQuiz();
    for (final w in current().words) {
      talk.matchQuiz(w.rowId, w.rowId);
    }
    talk.nextQuiz();
    final step = current();
    expect(step.kind, TalkQuizKind.selfCheck);
    expect(step.word.word, 'shore');
    expect(step.afterMistake, isTrue);
    expect(step.side, 'uk');

    await talk.rateQuiz(SelfRating.hard);
    final shore = (await store.byId(id))!.boxes.singleWhere((b) => b.rowId == 'q1');
    expect(shore.box, 2, reason: 'Hard: one box down, saved before the talk ends');
    expect(shore.lastCheckSide, 'uk');
    expect(shore.dueAt, DateTime(2026, 10, 30 + intervalDays(2)));
    expect(c.read(talkProvider(id, learnFlow: true)).openQuiz, isNull);

    await talk.finish();
    expect(flow.recorded!['q1'], DialogWordResult.missed);
    final after = (await store.byId(id))!.boxes;
    expect([for (final b in after) (b.rowId, b.box)], [('q1', 2)], reason: 'the end moves no box');
  });

  test('a wrong quick-check answer counts as missed', () {
    expect(dialogResultOf(WordOutcome.missed), DialogWordResult.missed);
  });

  test('the daily limit refuses the dialog in the flow', () async {
    final id = await newCollection();
    final api = FakeTalkApi()..answers.add(TalkApiException(TalkApiError.dayLimit, 'status 429'));
    final (:c, :talk, :flow, pictures: _) = container(id, api, setupOf(id));
    await talk.startFlow();
    expect(flow.refused, 1);
    expect(flow.recorded, isNull);
    expect(c.read(talkProvider(id, learnFlow: true)).status, TalkStatus.limit);
  });

  test('a plain talk of the same collection is a separate talk and still moves boxes', () async {
    final id = await newCollection();
    final api = FakeTalkApi()..answers.add(const TalkTurn(reply: 'Hi!', target: 'ticket'));
    final (:c, talk: _, :flow, pictures: _) = container(id, api, setupOf(id));
    c.listen(talkProvider(id), (_, __) {}, fireImmediately: true);
    final plain = c.read(talkProvider(id).notifier);
    await plain.start(split: false, now: DateTime(2026, 10, 30, 10));
    expect(api.flows.single.topic, isNull);
    expect(api.flows.single.maxReplies, isNull);
    await plain.send('A ticket for the crowded bus');
    await plain.finish(now: DateTime(2026, 10, 30, 10));
    expect(flow.recorded, isNull);
    expect(c.read(lastSessionResultProvider)?.kind, SessionKind.talk);
    expect((await store.byId(id))!.boxes.where((b) => b.rowId == 'r2').single.box, 1);
  });

  group('screen', () {
    Future<(_FakeFlow, GoRouter)> open(WidgetTester t, FakeTalkApi api) async {
      SharedPreferences.setMockInitialValues({});
      late String id;
      await t.runAsync(() async => id = await newCollection());
      final flow = _FakeFlow(setupOf(id));
      final router = GoRouter(initialLocation: '/', routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('flow screen'))),
        GoRoute(
            path: '/talk',
            builder: (_, s) => TalkScreen(collectionId: s.uri.queryParameters['collectionId'], learnFlow: true)),
      ]);
      addTearDown(router.dispose);
      final c = ProviderContainer(overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        storyRunStoreProvider.overrideWith((ref) async => runs),
        talkApiServiceProvider.overrideWithValue(api),
        talkPictureServiceProvider.overrideWithValue(FakeTalkPicture()),
        learnApiServiceProvider.overrideWithValue(FakeQuizData()),
        learnFlowProvider(id).overrideWith(() => flow),
      ]);
      addTearDown(c.dispose);
      c.listen(learnFlowProvider(id), (_, __) {}, fireImmediately: true);
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp.router(routerConfig: router)));
      router.push('/talk?collectionId=$id');
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      await settle(t);
      return (flow, router);
    }

    testWidgets('the daily limit goes back to the flow', (t) async {
      final api = FakeTalkApi()..answers.add(TalkApiException(TalkApiError.dayLimit, 'status 429'));
      final (flow, _) = await open(t, api);
      await t.pump(const Duration(milliseconds: 800));
      expect(flow.refused, 1);
      expect(find.text('flow screen'), findsOneWidget);
      expect(find.byType(TalkScreen), findsNothing);
    });

    testWidgets('the counter shows the reply limit; the end goes back to the flow', (t) async {
      final api = FakeTalkApi()..answers.add(const TalkTurn(reply: 'Hi!', target: 'crowded', interaction: 'complete'));
      final (flow, _) = await open(t, api);
      expect(find.text('0 / 6'), findsOneWidget);
      await t.tap(find.text('See results'));
      await t.pump();
      await settle(t);
      await t.pump(const Duration(milliseconds: 800));
      expect(flow.recorded, isNotNull);
      expect(find.text('flow screen'), findsOneWidget);
    });
  });
}

/// Lets the notifier's real async work (Isar, prefs) finish.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump();
  }
}
