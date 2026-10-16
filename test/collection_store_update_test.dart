import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/dialogues/dialogue_push.dart';
import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/offered_ai.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/exam_result_sink.dart';
import 'package:flutter_vocabulary_app/core/services/story_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/story_picture_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/story/story_run_tracker.dart';
import 'package:flutter_vocabulary_app/core/story/word_grouping.dart';
import 'package:flutter_vocabulary_app/core/story/word_groups_notifier.dart';

import 'seed_collections.dart';

/// collections-screen T7 (ADR-0006, sad §6 F10): CollectionStore.update reads,
/// changes and writes one record in one transaction, never touches filing and
/// never re-creates an erased record; every background writer goes through it
/// (AC-11, AC-27).

/// A Worker the test controls, for word grouping and story runs.
class FakeStoryApi extends StoryApiService {
  Future<List<SplitGroup>> Function(List<GroupingWord>, List<WordGroup>)? reply;
  final Map<String, List<StepStatus>> worker = {};
  final Map<String, Uint8List?> pictures = {};

  @override
  Future<List<SplitGroup>> group(List<GroupingWord> words, List<WordGroup> keep) =>
      reply!(words, keep);

  @override
  Future<StoryActionResult> startRun({
    required String runId,
    required List<String> words,
    required String storyModel,
    required String promptModel,
    required String pictureModel,
    String? sceneText,
  }) async {
    worker[runId] = [];
    return const StoryStarted();
  }

  @override
  Future<List<RunStatus>> status(List<String> runIds) async => [
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

  @override
  Future<Uint8List?> picture(String runId, int attempt) async => pictures['$runId:$attempt'];
}

StepStatus step(String role, {String? text, String modelId = 'claude-sonnet-5-5'}) => StepStatus(
      role: role,
      attempt: 1,
      modelId: modelId,
      outcome: 'done',
      text: text,
      missedWords: const [],
      priceUsd: 0.01,
      ms: 1200,
    );

WordPair row(String id, String word) => WordPair(word: word, translation: 'п', rowId: id);

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
  late CollectionStore store;
  late StoryRunStore runStore;
  late FakeStoryApi api;
  late WordCollection current;
  late WordCollection history;
  late List<http.Request> requests;
  ProviderContainer? container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('collection_store_update_test');
    store = await CollectionStore.open(directory: dir.path);
    runStore = await StoryRunStore.open(directory: dir.path);
    api = FakeStoryApi();
    requests = [];
    onRequest = null;
    current = WordCollection.create()
      ..words = [row('c1', 'now')]
      ..lastLocalModifiedAt = DateTime.now();
    await seedCollection(store, current);
    await store.setCurrentCollectionId(current.collectionId);
    history = WordCollection.create()
      ..words = [for (var i = 1; i <= 25; i++) row('r$i', 'w$i')]
      ..name = 'Old trip'
      ..order = 1
      ..keep = true
      ..lastLocalModifiedAt = DateTime.now().subtract(const Duration(days: 3));
    await seedCollection(store, history);
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ProviderContainer start() => container = ProviderContainer(overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        storyRunStoreProvider.overrideWith((ref) async => runStore),
        storyApiServiceProvider.overrideWithValue(api),
        storyPictureStoreProvider.overrideWithValue(
            StoryPictureStore(directory: dir.path, compress: (b, q) async => b)),
        offeredAisProvider.overrideWith((ref) async => OfferedAiList.fallback),
        storyPollIntervalProvider.overrideWithValue(const Duration(milliseconds: 30)),
        storyRunStartHookProvider.overrideWithValue((collectionId, group) async {}),
        dialoguePushServiceProvider.overrideWithValue(DialoguePushService(
          client: MockClient((request) async {
            requests.add(request);
            await onRequest?.call();
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
        )),
        dialoguePushPauseProvider.overrideWithValue(const Duration(milliseconds: 20)),
      ]);

  Isar isar() => Isar.getInstance('vocab')!;

  Future<WordCollection?> raw(String id) =>
      isar().wordCollections.filter().collectionIdEqualTo(id).findFirst();

  /// A filing change written straight to the record, the way T8's rename,
  /// move and bin transactions write it, plus a tag written by someone else.
  Future<void> fileAway(String id) => isar().writeTxn(() async {
        final c = (await raw(id))!;
        c
          ..name = 'Renamed'
          ..folderId = 'folder-1'
          ..order = 7
          ..binnedAt = DateTime(2026, 10, 16, 9)
          ..binnedFromFolderId = 'folder-0'
          ..tags = [...c.tags, 'other-writer'];
        await isar().wordCollections.put(c);
      });

  Future<void> expectFiledAway(String id) async {
    final c = (await raw(id))!;
    expect(c.name, 'Renamed');
    expect(c.folderId, 'folder-1');
    expect(c.order, 7);
    expect(c.binnedAt, DateTime(2026, 10, 16, 9));
    expect(c.binnedFromFolderId, 'folder-0');
    expect(c.keep, isTrue);
    expect(c.tags, contains('other-writer'), reason: 'the writer changes only its own fields');
  }

  Future<void> expectErased(String id) async {
    expect(await raw(id), isNull, reason: 'an erased collection never comes back');
  }

  group('CollectionStore.update', () {
    test('changes the stored record and says so', () async {
      final ok = await store.update(history.collectionId, (c) => c.tags = ['t1']);

      expect(ok, isTrue);
      expect((await raw(history.collectionId))!.tags, ['t1']);
      expect((await raw(history.collectionId))!.words, hasLength(25));
    });

    test('a gone record: false, nothing written, the change never runs', () async {
      await store.delete(history.collectionId);
      var ran = false;

      final ok = await store.update(history.collectionId, (c) => ran = true);

      expect(ok, isFalse);
      expect(ran, isFalse);
      await expectErased(history.collectionId);
    });

    test('the filing fields come back from the stored record even if the change touches them',
        () async {
      final ok = await store.update(history.collectionId, (c) {
        c
          ..name = 'Hijacked'
          ..folderId = 'elsewhere'
          ..order = 99
          ..binnedAt = DateTime(2020)
          ..binnedFromFolderId = 'x'
          ..keep = false
          ..tags = ['mine'];
      });

      expect(ok, isTrue);
      final c = (await raw(history.collectionId))!;
      expect(c.name, 'Old trip');
      expect(c.folderId, isNull);
      expect(c.order, 1);
      expect(c.binnedAt, isNull);
      expect(c.binnedFromFolderId, isNull);
      expect(c.keep, isTrue);
      expect(c.tags, ['mine']);
    });

    test('read, change and write are one transaction: concurrent updates lose nothing', () async {
      await Future.wait([
        for (var i = 0; i < 20; i++)
          store.update(history.collectionId, (c) => c.tags = [...c.tags, 't$i']),
      ]);

      expect((await raw(history.collectionId))!.tags, hasLength(20));
    });

    test('appendResult goes through it: filing kept, an erased record gets no result', () async {
      final sink = StoreExamResultSink(() async => store);
      await fileAway(history.collectionId);
      await sink.record(
          collectionId: history.collectionId,
          rowId: 'r1',
          exerciseId: 'quiz',
          label: WordResultLabel.values.first);
      await expectFiledAway(history.collectionId);
      expect((await raw(history.collectionId))!.results, hasLength(1));

      await store.delete(history.collectionId);
      expect(
          await store.appendResult(history.collectionId,
              WordResult()..rowId = 'r1'..exerciseId = 'quiz'..label = WordResultLabel.values.first..at = DateTime.now()),
          isFalse);
      await expectErased(history.collectionId);
    });
  });

  group('word grouping (word_groups_notifier)', () {
    List<SplitGroup> split(List<GroupingWord> w, List<WordGroup> k) => [
          SplitGroup(name: 'Food', rowIds: [for (var i = 1; i <= 13; i++) 'r$i']),
          SplitGroup(name: 'Travel', rowIds: [for (var i = 14; i <= 25; i++) 'r$i']),
        ];

    test('a filing change while the Worker splits survives the save', () async {
      api.reply = (w, k) async {
        await fileAway(history.collectionId);
        return split(w, k);
      };
      final c = start();

      await c.read(wordGroupsNotifierProvider(history.collectionId).notifier).ensureGrouped();

      await expectFiledAway(history.collectionId);
      expect((await raw(history.collectionId))!.groups.map((g) => g.name), ['Food', 'Travel']);
    });

    test('a collection erased while the Worker splits stays erased', () async {
      api.reply = (w, k) async {
        await store.delete(history.collectionId);
        return split(w, k);
      };
      final c = start();

      await c.read(wordGroupsNotifierProvider(history.collectionId).notifier).ensureGrouped();

      await expectErased(history.collectionId);
    });
  });

  group('story runs (story_run_tracker)', () {
    late WordGroup hGroup;

    Future<String> startRun(ProviderContainer c) async {
      hGroup = WordGroup()
        ..id = 'hg'
        ..name = 'Old'
        ..rowIds = [for (var i = 1; i <= 8; i++) 'r$i'];
      await store.update(history.collectionId, (h) => h.groups = [hGroup]);
      final id = (await c.read(storyRunTrackerProvider.notifier).startFor(history.collectionId, hGroup))!;
      api.worker[id] = [
        step('story', text: 'A story with w1 w2.'),
        step('prompt', text: 'A picture of food'),
        step('picture', modelId: 'grok-imagine-image'),
      ];
      api.pictures['$id:1'] = Uint8List.fromList([1, 2, 3]);
      return id;
    }

    test('a filing change while the run is out survives the finished story', () async {
      final c = start();
      final id = await startRun(c);
      await fileAway(history.collectionId);

      await c.read(storyRunTrackerProvider.notifier).poll();

      await expectFiledAway(history.collectionId);
      expect((await raw(history.collectionId))!.groups.single.storyRunId, id);
    });

    test('a collection erased while the run is out gets no story', () async {
      final c = start();
      await startRun(c);
      await store.delete(history.collectionId);

      await c.read(storyRunTrackerProvider.notifier).poll();

      await expectErased(history.collectionId);
    });
  });

  group('dialogue delivery (dialogue_push)', () {
    Future<void> sharedWithPicture() async {
      await store.update(history.collectionId, (h) {
        h
          ..publishedId = 'pub'
          ..editToken = 'tok'
          ..dialogues = [
            FilmDialogue()
              ..id = 'd1'
              ..lines = ['The attic.']
              ..wordRowIds = ['r1']
              ..pushState = PushState.delivered
              ..scenePictureRunId = 'run-1'
              ..picturePushState = PushState.pending,
          ];
      });
      await runStore.put(StoryRun()
        ..runId = 'run-1'
        ..collectionId = history.collectionId
        ..groupId = 'dialogue-d1'
        ..groupName = 'The attic.'
        ..startedAt = DateTime(2026, 10, 13)
        ..kind = StoryRunKind.scene
        ..outcome = 'done'
        ..collected = true
        ..steps = [
          StoryStep()
            ..role = 'picture'
            ..attempt = 1
            ..outcome = 'done'
            ..picturePath = 'x',
        ]);
      await StoryPictureStore(directory: dir.path, compress: (b, q) async => b)
          .write('run-1', 1, Uint8List.fromList([1, 2, 3]));
    }

    test('a filing change during the upload survives the delivered mark', () async {
      await sharedWithPicture();
      onRequest = () => fileAway(history.collectionId);
      final c = start();

      await c.read(dialoguePushProvider.notifier).run();

      expect(requests, hasLength(1));
      await expectFiledAway(history.collectionId);
      expect((await raw(history.collectionId))!.dialogues.single.picturePushState, PushState.delivered);
    });

    test('a collection erased during the upload stays erased', () async {
      await sharedWithPicture();
      onRequest = () => store.delete(history.collectionId);
      final c = start();

      await c.read(dialoguePushProvider.notifier).run();

      expect(requests, hasLength(1));
      await expectErased(history.collectionId);
    });
  });
}

/// Runs inside the fake Worker's answer, between a writer's read and its write.
Future<void> Function()? onRequest;
