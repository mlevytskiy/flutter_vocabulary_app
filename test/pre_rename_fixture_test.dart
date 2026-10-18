import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/tag_rules.dart';

/// AC-04 / ADR-0002: `test/fixtures/pre_rename_vocab/vocab.isar` was written
/// by the build from before Session was renamed to WordCollection, and
/// `expected.json` is what that build read back from it. The renamed build
/// must open the same file and read every collection, word, source, group,
/// dialogue, result, tag and story run unchanged, through the pinned stored
/// names (`Session`, `sessionId`).
/// What Isar reads for an `int` property a stored record does not have.
const _isarNullLong = -9223372036854775808;

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
    final isar = await Isar.open(
        [WordCollectionSchema, StoryRunSchema, CollectionFolderSchema],
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
      // collections-screen T5: the filing fields of pre-feature records read
      // as null / false. Isar skips Dart defaults for a property the record
      // lacks, so `order` reads as Isar's null long, not 0, until the
      // backfill (T6) numbers every record with no name.
      for (final c in collections) {
        expect(c.name, isNull);
        expect(c.folderId, isNull);
        expect(c.order, _isarNullLong);
        expect(c.binnedAt, isNull);
        expect(c.binnedFromFolderId, isNull);
        expect(c.keep, isFalse);
      }
      expect(await isar.collectionFolders.count(), 0);

      expect([
        for (final c in collections) _utc({'id': c.id, ...c.toJson()})
      ], expected['sessions']);
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

  test(
      'opened by this build, the fixture keeps its counts and gains names '
      '(T6 backfill)', () async {
    final store = await CollectionStore.open(directory: dir.path);
    try {
      final isar = Isar.getInstance('vocab')!;
      final collections = await isar.wordCollections.where().findAll();
      expect(collections, hasLength(4));
      expect(collections.expand((c) => c.words), hasLength(9));
      expect(collections.expand((c) => c.sources), hasLength(9));
      expect(collections.expand((c) => c.groups), hasLength(6));
      expect(collections.expand((c) => c.dialogues), hasLength(6));
      expect(collections.expand((c) => c.results), hasLength(6));
      // collection-tags T6: the legacy tags are emptied and move, spelling
      // kept, into the typed lists; nothing is lost.
      expect(collections.expand((c) => c.tags), isEmpty);
      // Source tags are copied up, so each collection's typed lists hold its
      // own and its sources' legacy tags once each, ignoring case.
      final legacyTexts = [
        for (final s in expected['sessions'] as List)
          ...mergeCaseDuplicates([
            ...(s['tags'] as List).cast<String>(),
            for (final src in s['sources'] as List)
              ...((src['tags'] as List?) ?? const []).cast<String>(),
          ]),
      ];
      final typedTexts = [
        for (final c in collections) ...[...c.originTags, ...c.topicTags],
      ];
      expect(typedTexts..sort(), equals([...legacyTexts]..sort()));
      expect(await isar.storyRuns.count(), 3);
      expect([
        for (final c in collections) _utc({'id': c.id, ...c.toJson()})
      ], [
        for (final s in expected['sessions'] as List) _migrated(s)
      ]);
      for (final c in collections) {
        final moment = creationMomentOf(c.collectionId);
        expect(moment, isNotNull);
        // collection-naming: a date name stays only with 5 words or more.
        final words = c.words.where((w) => w.word.trim().isNotEmpty).length;
        expect(
            c.name,
            words >= 5
                ? defaultCollectionName(moment!)
                : predicate<String>(isVocabularyName, 'a Vocabulary name'));
        expect(c.folderId, isNull);
        expect(c.keep,
            !c.isEmpty || c.originTags.isNotEmpty || c.topicTags.isNotEmpty);
      }
      final byMoment = [...collections]..sort((a, b) =>
          creationMomentOf(a.collectionId)!
              .compareTo(creationMomentOf(b.collectionId)!));
      expect([for (final c in byMoment) c.order], [0, 1, 2, 3]);
    } finally {
      await store.close();
    }
  });
}

/// A fixture collection as the T6 tag migration leaves it: legacy `tags`
/// sorted into origin / topic (case duplicates merged), emptied, and the
/// sources' typed tags copied up to the collection.
Map<String, dynamic> _migrated(Map<String, dynamic> session) {
  final out = jsonDecode(jsonEncode(session)) as Map<String, dynamic>;
  List<String> add(List<String> list, List<String> more) {
    final keys = {for (final t in list) tagKey(t)};
    return [
      ...list,
      for (final t in more)
        if (keys.add(tagKey(t))) t,
    ];
  }

  var origin = <String>[];
  var topic = <String>[];
  void move(List<String> tags, Map<String, dynamic> into) {
    final sorted = sortLegacyTags(tags);
    final o = mergeCaseDuplicates(sorted.origin);
    final t = mergeCaseDuplicates(sorted.topic);
    origin = add(origin, o);
    topic = add(topic, t);
    if (into != out) {
      if (o.isNotEmpty) into['originTags'] = o;
      if (t.isNotEmpty) into['topicTags'] = t;
    }
  }

  move((out['tags'] as List).cast<String>(), out);
  for (final src in out['sources'] as List) {
    final tags = ((src['tags'] as List?) ?? const []).cast<String>();
    if (tags.isEmpty) continue;
    src.remove('tags');
    move(tags, src as Map<String, dynamic>);
  }
  out['tags'] = <String>[];
  if (origin.isNotEmpty) out['originTags'] = origin;
  if (topic.isNotEmpty) out['topicTags'] = topic;
  return out;
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
