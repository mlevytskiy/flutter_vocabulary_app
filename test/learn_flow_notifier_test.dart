import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/learn_topics_service.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/talk_picture_service.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_stories.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_words.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/learn_flow_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/story_slots.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';

/// learn-welcome T10 (ADR-0001, ADR-0004; AC-01, AC-08, AC-09, AC-13, AC-16):
/// the LearnFlow notifier over fakes of the store, the story runs, the
/// tracker, the topics and the picture, with a fixed clock.

final _now = DateTime(2026, 10, 30, 10);

class _OtherCurrent extends WordsNotifier {
  @override
  Future<WordCollection> build() async => WordCollection.create()..collectionId = 'other';
}

class _Store implements CollectionStore {
  _Store(this.collection);
  final WordCollection collection;
  int updates = 0;

  @override
  Future<WordCollection?> byId(String collectionId) async => collectionId == collection.collectionId ? collection : null;

  @override
  Future<bool> update(String collectionId, void Function(WordCollection) change) async {
    updates++;
    change(collection);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected ${i.memberName}');
}

class _Runs implements StoryRunStore {
  final runs = <StoryRun>[];
  final _changes = StreamController<void>.broadcast();

  void emit(StoryRun run) {
    runs
      ..removeWhere((r) => r.runId == run.runId)
      ..insert(0, run);
    _changes.add(null);
  }

  @override
  Future<List<StoryRun>> newestFirst() async => [...runs];

  @override
  Stream<StoryRun?> watch(String runId) async* {
    yield runs.where((r) => r.runId == runId).firstOrNull;
    await for (final _ in _changes.stream) {
      yield runs.where((r) => r.runId == runId).firstOrNull;
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected ${i.memberName}');
}

class _Tracker extends StoryRunTracker {
  final started = <WordGroup>[];
  final replacing = <bool>[];
  final extras = <List<Map<String, String>>?>[];
  int follows = 0;
  int released = 0;
  bool refuse = false;

  @override
  StoryTrackerState build() => const StoryTrackerState();

  @override
  StoryFollow follow() {
    follows++;
    return StoryFollow.forTest(() => released++);
  }

  @override
  Future<String?> startFor(String collectionId, WordGroup group,
      {bool replacing = false, List<Map<String, String>>? extras}) async {
    started.add(group);
    this.extras.add(extras);
    this.replacing.add(replacing);
    return refuse ? null : 'run-${started.length}';
  }
}

class _Topics extends LearnTopicsService {
  final asked = <List<String>>[];

  @override
  Future<List<LearnTopic>> pick(List<String> words) async {
    asked.add(words);
    return LearnTopicsService.bundled;
  }
}

class _Picture extends TalkPictureService {
  final prompts = <String>[];
  final bytes = Completer<Uint8List?>();

  @override
  Future<Uint8List?> draw(String prompt) {
    prompts.add(prompt);
    return bytes.future;
  }
}

WordPair _pair(int i, {String? source}) =>
    WordPair(word: 'word$i', translation: 'слово$i', rowId: 'r$i', sourceId: source);

WordCollection _collection(int count) => WordCollection.create()
  ..collectionId = 'c1'
  ..words = [for (var i = 0; i < count; i++) _pair(i)];

StoryRun _run(String runId, String groupId, {String outcome = 'done', bool picture = true}) => StoryRun()
  ..runId = runId
  ..collectionId = 'c1'
  ..groupId = groupId
  ..groupName = 'g'
  ..startedAt = _now
  ..outcome = outcome
  ..collected = outcome != 'running'
  ..steps = [
    StoryStep()
      ..role = 'story'
      ..outcome = 'done',
    if (outcome == 'done')
      StoryStep()
        ..role = 'picture'
        ..outcome = 'done'
        ..picturePath = picture ? '/p/$runId.jpg' : null,
  ];

class _Flow {
  _Flow(this.container, this.store, this.runs, this.tracker, this.topics, this.picture);
  final ProviderContainer container;
  final _Store store;
  final _Runs runs;
  final _Tracker tracker;
  final _Topics topics;
  final _Picture picture;

  LearnFlow get notifier => container.read(learnFlowProvider('c1').notifier);
  LearnFlowState get state => container.read(learnFlowProvider('c1'));

  Future<void> settle() => pumpEventQueue();

  Future<void> open({FlowMode mode = FlowMode.easy}) async {
    notifier.chooseTopic(LearnTopicsService.bundled.first);
    notifier.chooseMode(mode);
    await settle();
  }

  Future<void> rateAll(SelfRating r, int count) async {
    for (var i = 0; i < count; i++) {
      await notifier.rate(r);
    }
    await settle();
  }
}

Future<_Flow> _flow(WordCollection collection, {_Runs? runs, _Tracker? tracker}) async {
  final store = _Store(collection);
  final r = runs ?? _Runs();
  final t = tracker ?? _Tracker();
  final topics = _Topics();
  final picture = _Picture();
  final c = ProviderContainer(overrides: [
    wordsProvider.overrideWith(_OtherCurrent.new),
    collectionStoreProvider.overrideWith((ref) async => store),
    storyRunStoreProvider.overrideWith((ref) async => r),
    storyRunTrackerProvider.overrideWith(() => t),
    learnTopicsServiceProvider.overrideWithValue(topics),
    talkPictureServiceProvider.overrideWithValue(picture),
    learnFlowClockProvider.overrideWithValue(() => _now),
  ]);
  addTearDown(c.dispose);
  c.listen(learnFlowProvider('c1'), (_, __) {});
  c.listen(learnFlowDialogSetupProvider('c1'), (_, __) {});
  await pumpEventQueue();
  return _Flow(c, store, r, t, topics, picture);
}

void main() {
  test('AC-01: fewer than 4 words refuses; no topics are asked', () async {
    final f = await _flow(_collection(3));
    expect(f.state.phase, FlowPhase.refused);
    expect(f.topics.asked, isEmpty);
    expect(flowTooFewWordsMessage, 'Add at least 4 words to learn');
  });

  test('build: warm-up with the card words, their groups and the topics', () async {
    final f = await _flow(_collection(16));
    expect(f.state.phase, FlowPhase.warmUp);
    expect(f.state.words.map((w) => w.rowId), [for (var i = 0; i < 16; i++) 'r$i']);
    expect(f.state.groups.map((g) => g.length), [12, 4]);
    expect(f.topics.asked.single, [for (var i = 0; i < 16; i++) 'word$i']);
    expect(f.state.topics, LearnTopicsService.bundled);
    expect(f.tracker.started, isEmpty, reason: 'stories start with the cards');
  });

  test('AC-04: own topic is taken as it is, up to 80 characters, never blank', () async {
    final f = await _flow(_collection(5));
    expect(f.notifier.ownTopic('   '), isFalse);
    expect(f.notifier.ownTopic('x' * 81), isFalse);
    expect(f.state.topic, isNull);
    expect(f.notifier.ownTopic(' My cat ${'y' * 70}'), isTrue);
    expect(f.state.topic!.isOwn, isTrue);
    expect(f.state.topic!.text, ' My cat ${'y' * 70}');
    expect(f.state.phase, FlowPhase.warmUp, reason: 'the mode is still missing');
    f.notifier.chooseMode(FlowMode.hard);
    await f.settle();
    expect(f.state.phase, FlowPhase.cards);
    expect(f.state.mode, FlowMode.hard);
    expect(f.picture.prompts.single, contains('My cat'));
  });

  test('AC-09: entering the cards starts one run per story group, follows them, draws the picture', () async {
    final f = await _flow(_collection(16));
    await f.open();
    expect(f.state.phase, FlowPhase.cards);
    expect(f.state.slot, isA<CardSlot>());
    expect(f.state.card!.rowId, 'r0');
    expect(f.tracker.started.map((g) => g.rowIds.length), [12, 4]);
    expect(f.tracker.extras.first, storyExtras(f.state.groups.first),
        reason: 'AC-12: the run gets the group rows\' hints');
    expect(f.tracker.extras.first!.length, 12);
    expect(f.tracker.started.first.id, flowGroupId(f.state.groups.first));
    expect(f.tracker.replacing, [true, true]);
    expect(f.tracker.follows, 1);
    expect(f.state.stories.map((s) => s.status), [FlowStoryStatus.writing, FlowStoryStatus.writing]);
    expect(f.state.stories.map((s) => s.runId), ['run-1', 'run-2']);
    expect(f.picture.prompts.single, contains('Daily routine'));
  });

  test('AC-09 / Q9: a finished story with the same row ids is reused, no run starts', () async {
    final collection = _collection(16)
      ..groups = [
        WordGroup()
          ..id = 'page-group'
          ..rowIds = ['r15', 'r14', 'r13', 'r12'],
      ];
    final runs = _Runs();
    final rows = collection.words;
    runs.runs.addAll([
      _run('old-flow', flowGroupId(rows.take(12).toList())),
      _run('page-story', 'page-group'),
      // Same words but another set of rows: not reused.
      _run('other', flowGroupId(rows.take(11).toList())),
    ]);
    final f = await _flow(collection, runs: runs);
    await f.open();
    expect(f.tracker.started, isEmpty);
    expect(f.state.stories.map((s) => (s.runId, s.reused, s.status, s.picturePath)), [
      ('old-flow', true, FlowStoryStatus.ready, '/p/old-flow.jpg'),
      ('page-story', true, FlowStoryStatus.ready, '/p/page-story.jpg'),
    ]);
  });

  test('a run of these rows still going is followed, not started again; a refused start fails', () async {
    final collection = _collection(16);
    final runs = _Runs()..runs.add(_run('going', flowGroupId(collection.words.take(12).toList()), outcome: 'running'));
    final tracker = _Tracker()..refuse = true;
    final f = await _flow(collection, runs: runs, tracker: tracker);
    await f.open();
    expect(tracker.started.length, 1, reason: 'only the second group');
    expect(f.state.stories[0].runId, 'going');
    expect(f.state.stories[0].status, FlowStoryStatus.writing);
    expect(f.state.stories[1].status, FlowStoryStatus.failed);
  });

  test('AC-08 / ADR-0004: each rating writes its box and side at once, one update per card', () async {
    final collection = _collection(4)
      ..boxes = [
        WordBox()
          ..rowId = 'r1'
          ..word = 'word1'
          ..box = 3
          ..dueAt = DateTime(2026, 10, 29)
          ..lastCheckSide = 'uk',
      ];
    final f = await _flow(collection);
    await f.open();
    final first = f.state.card!;
    expect(f.state.sideOf(first), 'uk');
    await f.notifier.rate(SelfRating.easy);
    expect(f.store.updates, 1);
    final b0 = collection.boxes.firstWhere((b) => b.rowId == 'r0');
    expect((b0.box, b0.lastCheckSide, b0.dueAt), (1, 'uk', DateTime(2026, 10, 31)));

    final second = f.state.card!;
    expect(second.rowId, 'r1');
    expect(f.state.sideOf(second), 'en');
    await f.notifier.rate(SelfRating.hard);
    expect(f.store.updates, 2);
    final b1 = collection.boxes.firstWhere((b) => b.rowId == 'r1');
    expect((b1.box, b1.lastCheckSide), (2, 'en'));
    expect(collection.boxes.where((b) => b.rowId == 'r1').length, 1);
    expect(f.state.ratings, {'r0': SelfRating.easy, 'r1': SelfRating.hard});
  });

  test('AC-10 / AC-13: wait page opens the story when ready, then the dialog setup is handed over', () async {
    final f = await _flow(_collection(5));
    await f.open();
    await f.notifier.rate(SelfRating.dontRemember);
    await f.rateAll(SelfRating.medium, 3);
    await f.notifier.rate(SelfRating.hard);
    await f.settle();
    expect(f.state.slot, isA<WaitSlot>());
    expect(f.container.read(learnFlowDialogSetupProvider('c1')), isNull);

    f.runs.emit(_run('run-1', f.state.stories.single.groupId));
    await f.settle();
    expect(f.state.slot, isA<StorySlot>());
    expect(f.state.shownStories, [0]);

    f.notifier.storyDone();
    expect(f.state.phase, FlowPhase.dialog);
    final setup = f.container.read(learnFlowDialogSetupProvider('c1'))!;
    expect(setup.maxReplies, 6);
    expect(setup.mode, FlowMode.easy);
    expect(setup.topic.id, 'daily-routine');
    // min(6, ceil(5/2)) = 3, at least 4; I don't remember, then Hard, then list order.
    expect(setup.words.map((w) => w.rowId), ['r0', 'r4', 'r1', 'r2']);
    expect(setup.pictureLoading, isTrue);

    f.picture.bytes.complete(Uint8List.fromList([1, 2]));
    await f.settle();
    final drawn = f.container.read(learnFlowDialogSetupProvider('c1'))!;
    expect(drawn.pictureLoading, isFalse);
    expect(drawn.picture, [1, 2]);
  });

  test('AC-10: a skipped story still not ready is saved to Story runs', () async {
    final f = await _flow(_collection(4));
    await f.open(mode: FlowMode.hard);
    await f.rateAll(SelfRating.easy, 4);
    expect(f.state.slot, isA<WaitSlot>());
    f.notifier.skipStory(0);
    expect(f.state.phase, FlowPhase.dialog);
    expect(f.state.savedStories, [0]);
    expect(f.state.dialogSetup!.maxReplies, 12);

    f.notifier.recordDialog({'r0': DialogWordResult.used, 'r1': DialogWordResult.afterHint, 'r2': DialogWordResult.missed});
    final r = f.state.results!;
    expect(f.state.phase, FlowPhase.results);
    expect(r.storiesSaved.single.index, 0);
    expect(r.storiesShown, isEmpty);
    expect(r.talk, {
      DialogWordResult.used: 1,
      DialogWordResult.afterHint: 1,
      DialogWordResult.missed: 1,
      DialogWordResult.unused: 1,
    });
  });

  test('AC-14 / AC-15: dialog results move no box; results count ratings, moves and due tomorrow', () async {
    final collection = _collection(5)
      ..boxes = [
        WordBox()
          ..rowId = 'r1'
          ..word = 'word1'
          ..box = 3
          ..dueAt = DateTime(2026, 10, 29),
        WordBox()
          ..rowId = 'r2'
          ..word = 'word2'
          ..box = 2
          ..dueAt = DateTime(2026, 10, 29),
      ];
    final runs = _Runs()..runs.add(_run('kept', flowGroupId(collection.words)));
    final f = await _flow(collection, runs: runs);
    await f.open();
    await f.notifier.rate(SelfRating.easy); // r0 new → 1 (up), due tomorrow
    await f.notifier.rate(SelfRating.dontRemember); // r1 3 → 1 (down), due tomorrow
    await f.notifier.rate(SelfRating.medium); // r2 stays 2, due in 2 days
    await f.notifier.rate(SelfRating.easy); // r3 → 1 (up)
    await f.notifier.rate(SelfRating.easy); // r4 → 1 (up)
    await f.settle();
    expect(f.state.slot, isA<StorySlot>());
    f.notifier.storyDone();
    final writes = f.store.updates;
    f.notifier.recordDialog({'r1': DialogWordResult.missed});
    await f.settle();
    expect(f.store.updates, writes);

    final r = f.state.results!;
    expect(r.ratingCounts, {
      SelfRating.dontRemember: 1,
      SelfRating.hard: 0,
      SelfRating.medium: 1,
      SelfRating.easy: 3,
    });
    expect(r.movedUp, ['r0', 'r3', 'r4']);
    expect(r.movedDown, ['r1']);
    expect(r.dueTomorrow, 4);
    expect(r.storiesShown.single.reused, isTrue);
    expect(r.talkLimit, isFalse);
  });

  test('AC-13: a refused dialog goes to the results with the daily limit', () async {
    final f = await _flow(_collection(4), runs: _Runs()..runs.add(_run('kept', flowGroupId(_collection(4).words))));
    await f.open();
    await f.rateAll(SelfRating.medium, 4);
    f.notifier.storyDone();
    f.notifier.dialogRefused();
    expect(f.state.phase, FlowPhase.results);
    expect(f.state.results!.talkLimit, isTrue);
    expect(f.state.talkLimit, isTrue);
  });

  test('AC-16: leave keeps saved ratings, lets the runs go on and takes no more calls', () async {
    final f = await _flow(_collection(8));
    await f.open();
    await f.notifier.rate(SelfRating.easy);
    expect(f.store.updates, 1);
    f.notifier.leave();
    expect(f.tracker.released, 1);
    final before = f.state;
    await f.notifier.rate(SelfRating.easy);
    f.notifier.storyDone();
    await f.settle();
    expect(f.store.updates, 1);
    expect(f.state, same(before));
    expect(f.store.collection.boxes.single.rowId, 'r0');
  });
}
