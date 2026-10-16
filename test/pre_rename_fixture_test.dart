import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';

/// AC-04 / ADR-0002: `test/fixtures/pre_rename_vocab/vocab.isar` was written
/// by the build from before Session was renamed to WordCollection, and
/// `expected.json` is what that build read back from it. The renamed build
/// must open the same file and read every collection, word, source, group,
/// dialogue, result, tag and story run unchanged, through the pinned stored
/// names (`Session`, `sessionId`).
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

  const fixture = 'test/fixtures/pre_rename_vocab';
  late Directory dir;
  late Map<String, dynamic> expected;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Isar writes to the file it opens, so open a copy.
    dir = Directory.systemTemp.createTempSync('pre_rename_fixture_test');
    File('$fixture/vocab.isar').copySync('${dir.path}/vocab.isar');
    expected = jsonDecode(File('$fixture/expected.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('the renamed schema reads every pre-rename field unchanged', () async {
    final isar = await Isar.open([WordCollectionSchema, StoryRunSchema],
        directory: dir.path, name: 'vocab');
    try {
      final collections = await isar.wordCollections.where().findAll();
      final runs = await isar.storyRuns.where().findAll();

      expect(collections, hasLength(4));
      expect(collections.expand((c) => c.words), hasLength(9));
      expect(collections.expand((c) => c.sources), hasLength(9));
      expect(collections.expand((c) => c.groups), hasLength(6));
      expect(collections.expand((c) => c.dialogues), hasLength(6));
      expect(collections.expand((c) => c.results), hasLength(6));
      expect(collections.expand((c) => c.tags), hasLength(6));
      expect(runs, hasLength(3));

      expect([for (final c in collections) _utc({'id': c.id, ...c.toJson()})],
          expected['sessions']);
      expect([for (final r in runs) _runJson(r)], expected['storyRuns']);
    } finally {
      await isar.close();
    }
  });

  test('CollectionStore and StoryRunStore open the pre-rename database',
      () async {
    final store = await CollectionStore.open(directory: dir.path);
    final runs = await StoryRunStore.open(directory: dir.path);
    try {
      final first = await store.byId('mf1abc-1xyz');
      expect(first, isNotNull);
      expect(first!.collectionId, 'mf1abc-1xyz');
      expect(first.words.map((w) => w.word), ['apple1', 'pear1', 'plum1']);
      expect(await store.byId('mf0empty-0'), isNotNull);
      expect((await store.nonEmpty()).map((c) => c.collectionId),
          ['mf3abc-3xyz', 'mf2abc-2xyz', 'mf1abc-1xyz']);
      final run = await runs.byId('scene1');
      expect(run!.collectionId, 'mf1abc-1xyz');
      expect(run.kind, StoryRunKind.scene);
      expect((await runs.newestFirst()), hasLength(3));
    } finally {
      await store.close();
    }
  });
}

const _dateKeys = {'updatedAt', 'lastLocalModifiedAt', 'takenAt', 'at'};

dynamic _utc(dynamic v) {
  if (v is Map) {
    return {
      for (final e in v.entries)
        e.key: _dateKeys.contains(e.key) && e.value is String
            ? DateTime.parse(e.value as String).toUtc().toIso8601String()
            : _utc(e.value),
    };
  }
  if (v is List) return [for (final x in v) _utc(x)];
  return v;
}

Map<String, dynamic> _runJson(StoryRun r) => {
      'id': r.id,
      'runId': r.runId,
      'sessionId': r.collectionId,
      'groupId': r.groupId,
      'groupName': r.groupName,
      'words': r.words,
      'startedAt': r.startedAt.toUtc().toIso8601String(),
      'models': r.models,
      'steps': [
        for (final s in r.steps)
          {
            'role': s.role,
            'attempt': s.attempt,
            'modelId': s.modelId,
            'modelName': s.modelName,
            'outcome': s.outcome,
            'text': s.text,
            'picturePath': s.picturePath,
            'missedWords': s.missedWords,
            'priceUsd': s.priceUsd,
            'priceEstimated': s.priceEstimated,
            'ms': s.ms,
          }
      ],
      'outcome': r.outcome,
      'collected': r.collected,
      'kind': r.kind.name,
      'sceneText': r.sceneText,
    };
