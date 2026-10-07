import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as ft show group;
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/offered_ai.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/story_picture_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/core/story/word_groups_notifier.dart';

/// mnemonic-story T15: the story run tracker starts runs, follows them while a
/// screen is open and collects them (AC-06 – AC-10, AC-16, AC-19).

/// A Worker the test controls: it keeps the steps of each run it has started
/// and answers status, redo and picture calls from them.
class FakeStoryApi extends StoryApiService {
  final List<Map<String, dynamic>> starts = [];
  final List<List<String>> statusAsked = [];
  final List<Map<String, dynamic>> redos = [];
  final List<String> pictureAsked = [];

  /// The steps the Worker reports per run id; a run absent here is unknown.
  final Map<String, List<StepStatus>> worker = {};
  final Map<String, Uint8List?> pictures = {};

  StoryActionResult startResult = const StoryStarted();
  Object? startThrows;
  StoryActionResult redoResult = const StoryStarted();
  Object? statusThrows;

  @override
  Future<StoryActionResult> startRun({
    required String runId,
    required List<String> words,
    required String storyModel,
    required String promptModel,
    required String pictureModel,
  }) async {
    starts.add({
      'runId': runId,
      'words': words,
      'story': storyModel,
      'prompt': promptModel,
      'picture': pictureModel,
    });
    if (startThrows != null) throw startThrows!;
    if (startResult is StoryStarted) worker[runId] = [];
    return startResult;
  }

  @override
  Future<List<RunStatus>> status(List<String> runIds) async {
    statusAsked.add(runIds);
    if (statusThrows != null) throw statusThrows!;
    return [
      for (final id in runIds)
        if (worker.containsKey(id))
          RunStatus(
            runId: id,
            words: const [],
            storyModel: 'claude-sonnet-5-5',
            promptModel: 'claude-sonnet-5-5',
            pictureModel: 'grok-imagine-image',
            createdAt: null,
            steps: worker[id]!,
          ),
    ];
  }

  @override
  Future<StoryActionResult> redo({required String runId, required String step, String? pictureModel}) async {
    redos.add({'runId': runId, 'step': step, 'pictureModel': pictureModel});
    return redoResult;
  }

  @override
  Future<Uint8List?> picture(String runId, int attempt) async {
    pictureAsked.add('$runId:$attempt');
    return pictures['$runId:$attempt'];
  }
}

StepStatus step(
  String role, {
  int attempt = 1,
  String outcome = 'done',
  String? text,
  List<String> missed = const [],
  String modelId = 'claude-sonnet-5-5',
  double price = 0.01,
}) =>
    StepStatus(
      role: role,
      attempt: attempt,
      modelId: modelId,
      outcome: outcome,
      text: text,
      missedWords: missed,
      priceUsd: outcome == 'running' ? null : price,
      ms: outcome == 'running' ? null : 1200,
    );

final bytes = Uint8List.fromList([1, 2, 3, 4]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
  });

  late Directory dir;
  late SessionStore store;
  late StoryRunStore runStore;
  late FakeStoryApi api;
  late ProviderContainer container;
  late Session session;
  late WordGroup group;

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((ref) async => store),
        storyRunStoreProvider.overrideWith((ref) async => runStore),
        storyApiServiceProvider.overrideWithValue(api),
        storyPictureStoreProvider.overrideWithValue(
            StoryPictureStore(directory: dir.path, compress: (b, q) async => b)),
        offeredAisProvider.overrideWith((ref) async => OfferedAiList.fallback),
        storyPollIntervalProvider.overrideWithValue(const Duration(milliseconds: 30)),
      ]);

  Future<void> boot({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    dir = Directory.systemTemp.createTempSync('story_run_tracker_test');
    store = await SessionStore.open(directory: dir.path);
    runStore = await StoryRunStore.open(directory: dir.path);
    api = FakeStoryApi();
    session = Session.create();
    session.words = [for (var i = 1; i <= 8; i++) WordPair(word: 'w$i', translation: 'п', rowId: 'r$i')];
    group = WordGroup()
      ..id = 'g1'
      ..name = 'Food'
      ..rowIds = [for (var i = 1; i <= 8; i++) 'r$i'];
    session.groups = [group];
    session.selectedGroupId = 'g1';
    session.lastLocalModifiedAt = DateTime.now();
    await store.put(session);
    await store.setCurrentSessionId(session.sessionId);
    container = makeContainer();
  }

  tearDown(() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  StoryRunTracker tracker() => container.read(storyRunTrackerProvider.notifier);

  Future<Session> saved() async => (await store.byId(session.sessionId))!;

  Future<StoryRun> startedRun() async {
    final id = await tracker().startFor(session.sessionId, group);
    expect(id, isNotNull);
    return (await runStore.byId(id!))!;
  }

  /// The Worker finishes all three steps of [runId].
  void workerFinishes(String runId, {int attempt = 1}) {
    api.worker[runId] = [
      step('story', text: 'A story with w1 w2.'),
      step('prompt', text: 'A picture of food'),
      step('picture', attempt: attempt, modelId: 'grok-imagine-image', price: 0.02),
    ];
    api.pictures['$runId:$attempt'] = bytes;
  }

  test('startFor saves a running run with the resolved AIs and starts it on the Worker once (AC-06, AC-13)',
      () async {
    await boot(prefs: {'story_ai_story': 'gone-model', 'story_ai_story_name': 'Gone'});

    final run = await startedRun();

    expect(run.outcome, 'running');
    expect(run.collected, isFalse);
    expect(run.sessionId, session.sessionId);
    expect(run.groupId, 'g1');
    expect(run.groupName, 'Food');
    expect(run.words, [for (var i = 1; i <= 8; i++) 'w$i']);
    expect(run.models, ['claude-sonnet-5-5', 'claude-sonnet-5-5', 'grok-imagine-image'],
        reason: 'a saved AI that is no longer offered falls back to the default');
    expect(api.starts, hasLength(1));
    expect(api.starts.single['runId'], run.runId);
    expect(api.starts.single['story'], 'claude-sonnet-5-5');
    expect(api.starts.single['picture'], 'grok-imagine-image');
  });

  test('a run goes started, then each step, then collected, and becomes the group\'s story (AC-06, AC-16)',
      () async {
    await boot();
    final run = await startedRun();

    api.worker[run.runId] = [step('story', outcome: 'running')];
    await tracker().poll();
    var now = (await runStore.byId(run.runId))!;
    expect(now.outcome, 'running');
    expect(now.steps.map((s) => '${s.role}:${s.outcome}'), ['story:running']);

    api.worker[run.runId] = [
      step('story', text: 'A story with w1 w2.'),
      step('prompt', outcome: 'running'),
    ];
    await tracker().poll();
    now = (await runStore.byId(run.runId))!;
    expect(now.steps.map((s) => '${s.role}:${s.outcome}'), ['story:done', 'prompt:running']);
    expect(now.steps.first.text, 'A story with w1 w2.');
    expect(now.steps.first.modelName, 'Sonnet 5.5');
    expect(now.steps.first.priceUsd, 0.01);
    expect((await saved()).groups.single.storyRunId, isNull, reason: 'no picture yet');

    workerFinishes(run.runId);
    await tracker().poll();
    now = (await runStore.byId(run.runId))!;
    expect(now.outcome, 'done');
    expect(now.collected, isTrue);
    final pic = now.steps.firstWhere((s) => s.role == 'picture');
    expect(pic.picturePath, isNotNull);
    expect(File(pic.picturePath!).existsSync(), isTrue);
    expect(api.pictureAsked, ['${run.runId}:1']);

    final group1 = (await saved()).groups.single;
    expect(group1.storyRunId, run.runId);
    expect(group1.storyWords, [for (var i = 1; i <= 8; i++) 'w$i']);

    // Collected: nothing more to ask the Worker.
    final asked = api.statusAsked.length;
    await tracker().poll();
    expect(api.statusAsked, hasLength(asked));
  });

  test('a restart in the middle of a run collects it without a second start (AC-10)', () async {
    await boot();
    final run = await startedRun();
    api.worker[run.runId] = [step('story', text: 's'), step('prompt', outcome: 'running')];
    await tracker().poll();

    // The app is closed; the Worker finishes meanwhile; the app is reopened.
    container.dispose();
    workerFinishes(run.runId);
    container = makeContainer();
    await tracker().startup;

    final now = (await runStore.byId(run.runId))!;
    expect(now.outcome, 'done');
    expect(now.collected, isTrue);
    expect(api.starts, hasLength(1), reason: 'no second start, nothing paid again');
    expect((await saved()).groups.single.storyRunId, run.runId);
  });

  test('a failed new run leaves the old story; a run that finishes replaces it (AC-16)', () async {
    await boot();
    final old = await startedRun();
    workerFinishes(old.runId);
    await tracker().poll();
    expect((await saved()).groups.single.storyRunId, old.runId);
    final oldWords = (await saved()).groups.single.storyWords;

    group = (await saved()).groups.single;
    final replacement = await tracker().startFor(session.sessionId, group, replacing: true);
    expect(replacement, isNotNull);
    api.worker[replacement!] = [
      step('story', text: 's'),
      step('prompt', text: 'p'),
      step('picture', outcome: 'failed', modelId: 'grok-imagine-image'),
    ];
    await tracker().poll();

    final failed = (await runStore.byId(replacement))!;
    expect(failed.outcome, 'failed');
    expect(failed.collected, isTrue);
    expect((await saved()).groups.single.storyRunId, old.runId);
    expect((await saved()).groups.single.storyWords, oldWords);
    expect(await runStore.byId(old.runId), isNotNull, reason: 'earlier runs are never removed (AC-15)');

    final again = await tracker().startFor(session.sessionId, (await saved()).groups.single, replacing: true);
    workerFinishes(again!);
    await tracker().poll();
    expect((await saved()).groups.single.storyRunId, again);
  });

  test('a story that missed words stops the run with the words kept (AC-08)', () async {
    await boot();
    final run = await startedRun();
    api.worker[run.runId] = [
      step('story', outcome: 'failed', text: 'A story.', missed: ['w3']),
    ];
    await tracker().poll();

    final now = (await runStore.byId(run.runId))!;
    expect(now.outcome, 'failed');
    expect(now.collected, isTrue);
    expect(now.steps.single.missedWords, ['w3']);
    expect(now.steps.single.priceUsd, 0.01);
    expect((await saved()).groups.single.storyRunId, isNull);
  });

  test('redoPrompt asks the Worker to redo the prompt step and puts the run back in progress (AC-08b)',
      () async {
    await boot();
    final run = await startedRun();
    api.worker[run.runId] = [step('story', text: 's'), step('prompt', outcome: 'failed')];
    await tracker().poll();
    expect((await runStore.byId(run.runId))!.outcome, 'failed');

    final result = await tracker().redoPrompt(run.runId);

    expect(result, isA<StoryStarted>());
    expect(api.redos, [
      {'runId': run.runId, 'step': 'prompt', 'pictureModel': null},
    ]);
    final now = (await runStore.byId(run.runId))!;
    expect(now.outcome, 'running');
    expect(now.collected, isFalse);
    expect(now.steps.firstWhere((s) => s.role == 'prompt').outcome, 'running');

    // The run is followed again until it ends.
    workerFinishes(run.runId);
    await tracker().poll();
    expect((await runStore.byId(run.runId))!.outcome, 'done');
  });

  test('drawAgain redoes the picture with the picture maker chosen now and keeps the failed attempt (AC-09)',
      () async {
    await boot();
    final run = await startedRun();
    api.worker[run.runId] = [
      step('story', text: 's'),
      step('prompt', text: 'p'),
      step('picture', outcome: 'failed', modelId: 'grok-imagine-image'),
    ];
    await tracker().poll();

    api.redoResult = const StoryStarted(attempt: 2);
    final result = await tracker().drawAgain(run.runId);

    expect(result, isA<StoryStarted>());
    expect(api.redos, [
      {'runId': run.runId, 'step': 'picture', 'pictureModel': 'grok-imagine-image'},
    ]);
    var now = (await runStore.byId(run.runId))!;
    expect(now.outcome, 'running');
    expect(now.collected, isFalse);
    final pictures = now.steps.where((s) => s.role == 'picture').toList();
    expect([for (final p in pictures) '${p.attempt}:${p.outcome}'], ['1:failed', '2:running']);

    api.worker[run.runId] = [
      step('story', text: 's'),
      step('prompt', text: 'p'),
      step('picture', outcome: 'failed', modelId: 'grok-imagine-image'),
      step('picture', attempt: 2, modelId: 'grok-imagine-image', price: 0.02),
    ];
    api.pictures['${run.runId}:2'] = bytes;
    await tracker().poll();
    now = (await runStore.byId(run.runId))!;
    expect(now.outcome, 'done');
    expect(now.steps.where((s) => s.role == 'picture').map((s) => s.outcome), ['failed', 'done']);
    expect((await saved()).groups.single.storyRunId, run.runId);
  });

  test('a refused redo is recorded and leaves the run as it was (AC-19)', () async {
    await boot();
    final run = await startedRun();
    api.worker[run.runId] = [
      step('story', text: 's'),
      step('prompt', text: 'p'),
      step('picture', outcome: 'failed', modelId: 'grok-imagine-image'),
    ];
    await tracker().poll();

    api.redoResult = const StoryRefused(StoryRefusal.dayLimit);
    final result = await tracker().drawAgain(run.runId);

    expect(result, isA<StoryRefused>());
    expect((await runStore.byId(run.runId))!.outcome, 'failed');
    expect(container.read(storyRunTrackerProvider).refusals['g1']!.reason, StoryRefusal.dayLimit);
  });

  test('a day limit refusal marks the run not started and is recorded for the group (AC-19)', () async {
    await boot();
    api.startResult = const StoryRefused(StoryRefusal.dayLimit);

    final id = await tracker().startFor(session.sessionId, group);

    expect(id, isNull);
    final run = (await runStore.newestFirst()).single;
    expect(run.outcome, 'failed');
    expect(run.collected, isTrue);
    expect(run.steps, isEmpty);
    expect(container.read(storyRunTrackerProvider).refusals['g1']!.reason, StoryRefusal.dayLimit);
    expect(await runStore.uncollected(), isEmpty, reason: 'a run that never started is not followed');
  });

  test('a not-offered refusal records the AI and resets that step to its default (AC-13)', () async {
    await boot();
    api.startResult = const StoryRefused(StoryRefusal.notOffered, model: 'grok-imagine-image');

    await tracker().startFor(session.sessionId, group);

    final refusal = container.read(storyRunTrackerProvider).refusals['g1']!;
    expect(refusal.reason, StoryRefusal.notOffered);
    expect(refusal.aiName, 'Grok Imagine');
    expect(container.read(aiChoiceProvider).ids[AiRole.picture], 'grok-imagine-image');
    expect((await runStore.newestFirst()).single.collected, isTrue);
  });

  test('a start that could not reach the Worker leaves a run that was not started', () async {
    await boot();
    api.startThrows = StoryApiException(StoryApiError.network, 'offline');

    final id = await tracker().startFor(session.sessionId, group);

    expect(id, isNull);
    final run = (await runStore.newestFirst()).single;
    expect(run.outcome, 'failed');
    expect(run.collected, isTrue);
    expect(container.read(storyRunTrackerProvider).refusals['g1']!.reason, StoryRefusal.unavailable);
  });

  test('a run the Worker never knew is dropped from following after a while', () async {
    await boot();
    final run = StoryRun()
      ..runId = 'lost'
      ..sessionId = session.sessionId
      ..groupId = 'g1'
      ..groupName = 'Food'
      ..words = ['w1']
      ..startedAt = DateTime.now().subtract(const Duration(minutes: 10))
      ..models = ['claude-sonnet-5-5', 'claude-sonnet-5-5', 'grok-imagine-image'];
    await runStore.put(run);

    await tracker().poll();

    final now = (await runStore.byId('lost'))!;
    expect(now.outcome, 'failed');
    expect(now.collected, isTrue);
  });

  test('the automatic start never repeats for a group with a story, a run, or a failed run (AC-07)',
      () async {
    await boot();
    // a run in progress
    final first = await tracker().startFor(session.sessionId, group);
    expect(first, isNotNull);
    expect(await tracker().startFor(session.sessionId, group), isNull);
    expect(api.starts, hasLength(1));

    // a failed run waits for the learner's "Try again"
    api.worker[first!] = [step('story', outcome: 'failed', text: 's', missed: ['w1'])];
    await tracker().poll();
    expect(await tracker().startFor(session.sessionId, group), isNull);
    expect(api.starts, hasLength(1));

    // "Try again" is a start that replaces
    expect(await tracker().startFor(session.sessionId, group, replacing: true), isNotNull);
    expect(api.starts, hasLength(2));

    // a group that has a story
    final withStory = group.copy()..storyRunId = 'x';
    expect(await tracker().startFor(session.sessionId, withStory), isNull);
    expect(api.starts, hasLength(2));
  });

  test('the word-groups start hook starts a run through the tracker (AC-06)', () async {
    await boot();

    await container.read(storyRunStartHookProvider)(session.sessionId, group);

    expect(api.starts, hasLength(1));
  });

  test('a run for a History session is saved into that session, not the current one (AC-11)', () async {
    await boot();
    final history = Session.create();
    history.words = [for (var i = 1; i <= 8; i++) WordPair(word: 'h$i', translation: 'п', rowId: 'h$i')];
    final hGroup = WordGroup()
      ..id = 'hg'
      ..name = 'Old'
      ..rowIds = [for (var i = 1; i <= 8; i++) 'h$i'];
    history.groups = [hGroup];
    history.lastLocalModifiedAt = DateTime.now().subtract(const Duration(days: 3));
    await store.put(history);

    final id = await tracker().startFor(history.sessionId, hGroup);
    workerFinishes(id!);
    await tracker().poll();

    expect((await store.byId(history.sessionId))!.groups.single.storyRunId, id);
    expect((await saved()).groups.single.storyRunId, isNull);
  });

  ft.group('following', () {
    Future<StoryRun> runningRun() async {
      final run = await startedRun();
      api.worker[run.runId] = [step('story', outcome: 'running')];
      return run;
    }

    test('asks the Worker every interval while a screen follows, and stops when the last one lets go',
        () async {
      await boot();
      await runningRun();
      await tracker().startup;
      final base = api.statusAsked.length;

      final a = tracker().follow();
      final b = tracker().follow();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(api.statusAsked.length, greaterThan(base + 3));

      a.release();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final stillFollowed = api.statusAsked.length;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(api.statusAsked.length, greaterThan(stillFollowed), reason: 'one screen still follows');

      b.release();
      b.release(); // letting go twice changes nothing
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final stopped = api.statusAsked.length;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(api.statusAsked.length, stopped, reason: 'no follower, no polling');
    });

    test('does not poll without a follower, and not at all when nothing is uncollected', () async {
      await boot();
      await tracker().startup;
      final f = tracker().follow();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(api.statusAsked, isEmpty, reason: 'nothing uncollected: no call');
      f.release();

      await runningRun();
      final base = api.statusAsked.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(api.statusAsked.length, base, reason: 'a run in progress alone does not poll');
    });

    test('stops following once every run is collected', () async {
      await boot();
      final run = await runningRun();
      final f = tracker().follow();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      workerFinishes(run.runId);
      for (var i = 0; i < 100 && !(await runStore.byId(run.runId))!.collected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      expect((await runStore.byId(run.runId))!.collected, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final settled = api.statusAsked.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(api.statusAsked.length, settled);
      f.release();
    });

    test('backs off when the Worker says too many requests, and recovers after an answer', () async {
      await boot();
      await runningRun();
      await tracker().startup;
      api.statusThrows = StoryApiException(StoryApiError.rateLimited, 'status 429');

      await tracker().poll();
      expect(tracker().backoff, 2);
      await tracker().poll();
      expect(tracker().backoff, 4);

      api.statusThrows = null;
      await tracker().poll();
      expect(tracker().backoff, 1);
    });

    test('a network error neither throws nor stops following', () async {
      await boot();
      final run = await runningRun();
      await tracker().startup;
      api.statusThrows = StoryApiException(StoryApiError.network, 'offline');
      await tracker().poll();
      expect((await runStore.byId(run.runId))!.outcome, 'running');
    });
  });
}
