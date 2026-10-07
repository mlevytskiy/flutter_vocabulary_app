import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';

/// mnemonic-story T10: the stable row id, word groups in the session, and the
/// story run collection (ADR-0003). Hermetic, like session_store_test.dart.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('story_models_test');
    store = await SessionStore.open(directory: dir.path);
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('WordPair.rowId', () {
    test('copy keeps it', () {
      final pair = WordPair(word: 'a', translation: 'а', rowId: 'row-1');
      expect(pair.copy().rowId, 'row-1');
      expect(WordPair.fromJson(pair.toJson()).rowId, 'row-1');
    });

    test('a session saved without row ids gets stable ones on first read',
        () async {
      final session = Session.create()
        ..words = [
          WordPair(word: 'a', translation: 'а'),
          WordPair(word: 'b', translation: 'б'),
        ];
      expect(session.words.every((w) => w.rowId.isEmpty), isTrue);

      await store.put(session);
      final first = (await store.byId(session.sessionId))!;
      final ids = first.words.map((w) => w.rowId).toList();

      expect(ids.every((id) => id.isNotEmpty), isTrue);
      expect(ids.toSet().length, 2, reason: 'one distinct id per row');

      final second = (await store.byId(session.sessionId))!;
      expect(second.words.map((w) => w.rowId).toList(), ids);
      final listed = (await store.nonEmpty()).single;
      expect(listed.words.map((w) => w.rowId).toList(), ids);
    });

    test('saving again keeps the ids a row already has', () async {
      final session = Session.create()
        ..words = [WordPair(word: 'a', translation: 'а', rowId: 'keep-me')];
      await store.put(session);
      final back = (await store.byId(session.sessionId))!;
      expect(back.words.single.rowId, 'keep-me');

      back.words = [...back.words, WordPair(word: 'b', translation: 'б')];
      await store.put(back);
      final again = (await store.byId(session.sessionId))!;
      expect(again.words[0].rowId, 'keep-me');
      expect(again.words[1].rowId, isNotEmpty);
    });
  });

  group('Session groups', () {
    test('groups, the selected group and the key round-trip', () async {
      final session = Session.create()
        ..words = [
          WordPair(word: 'a', translation: 'а', rowId: 'r1'),
          WordPair(word: 'b', translation: 'б', rowId: 'r2'),
        ]
        ..groups = [
          WordGroup()
            ..id = 'g1'
            ..name = 'Animals'
            ..rowIds = ['r1', 'r2']
            ..storyRunId = 'run-1'
            ..storyWords = ['a', 'b'],
          WordGroup()
            ..id = 'g2'
            ..name = 'Rest',
        ]
        ..selectedGroupId = 'g1'
        ..groupedWordsKey = 'a|b';

      await store.put(session);
      final back = (await store.byId(session.sessionId))!;

      expect(back.groups.map((g) => g.id).toList(), ['g1', 'g2']);
      expect(back.groups[0].name, 'Animals');
      expect(back.groups[0].rowIds, ['r1', 'r2']);
      expect(back.groups[0].storyRunId, 'run-1');
      expect(back.groups[0].storyWords, ['a', 'b']);
      expect(back.groups[1].storyRunId, isNull);
      expect(back.groups[1].rowIds, isEmpty);
      expect(back.selectedGroupId, 'g1');
      expect(back.groupedWordsKey, 'a|b');
    });

    test('a session saved before groups existed reads back with none',
        () async {
      final session = Session.create()
        ..words = [WordPair(word: 'a', translation: 'а')];
      await store.put(session);
      final back = (await store.byId(session.sessionId))!;
      expect(back.groups, isEmpty);
      expect(back.selectedGroupId, isNull);
      expect(back.groupedWordsKey, isNull);
    });
  });

  group('StoryRun collection', () {
    StoryRun run(String runId, DateTime startedAt) => StoryRun()
      ..runId = runId
      ..sessionId = 's1'
      ..groupId = 'g1'
      ..groupName = 'Animals'
      ..words = ['cat', 'dog']
      ..startedAt = startedAt
      ..models = ['sonnet', 'sonnet', 'grok']
      ..outcome = 'running'
      ..steps = [
        StoryStep()
          ..role = 'story'
          ..attempt = 1
          ..modelId = 'sonnet'
          ..modelName = 'Sonnet 5.5'
          ..outcome = 'done'
          ..text = 'A cat chased a dog.'
          ..missedWords = []
          ..priceUsd = 0.012
          ..priceEstimated = false
          ..ms = 4100,
        StoryStep()
          ..role = 'picture'
          ..attempt = 2
          ..modelId = 'grok'
          ..modelName = 'Grok'
          ..outcome = 'failed'
          ..priceEstimated = true,
      ];

    test('a run with steps round-trips through Isar', () async {
      final isar = Isar.getInstance('vocab')!;
      final started = DateTime.utc(2026, 10, 7, 12);
      await isar.writeTxn(() => isar.storyRuns.put(run('run-1', started)));

      final back =
          await isar.storyRuns.filter().runIdEqualTo('run-1').findFirst();

      expect(back, isNotNull);
      expect(back!.sessionId, 's1');
      expect(back.groupId, 'g1');
      expect(back.groupName, 'Animals');
      expect(back.words, ['cat', 'dog']);
      expect(back.startedAt.toUtc(), started);
      expect(back.models, ['sonnet', 'sonnet', 'grok']);
      expect(back.outcome, 'running');
      expect(back.collected, isFalse);
      expect(back.steps.length, 2);
      final story = back.steps[0];
      expect(story.role, 'story');
      expect(story.attempt, 1);
      expect(story.modelId, 'sonnet');
      expect(story.modelName, 'Sonnet 5.5');
      expect(story.outcome, 'done');
      expect(story.text, 'A cat chased a dog.');
      expect(story.picturePath, isNull);
      expect(story.missedWords, isEmpty);
      expect(story.priceUsd, 0.012);
      expect(story.priceEstimated, isFalse);
      expect(story.ms, 4100);
      final pic = back.steps[1];
      expect(pic.outcome, 'failed');
      expect(pic.priceUsd, isNull);
      expect(pic.priceEstimated, isTrue);
      expect(pic.ms, isNull);
    });

    test('runId is unique: a second put replaces the first', () async {
      final isar = Isar.getInstance('vocab')!;
      final t = DateTime.utc(2026, 10, 7);
      await isar.writeTxn(() => isar.storyRuns.put(run('run-1', t)));
      await isar.writeTxn(
          () => isar.storyRuns.put(run('run-1', t)..groupName = 'Changed'));

      expect(await isar.storyRuns.count(), 1);
      final back =
          await isar.storyRuns.filter().runIdEqualTo('run-1').findFirst();
      expect(back!.groupName, 'Changed');
    });

    test('runs list newest first by startedAt', () async {
      final isar = Isar.getInstance('vocab')!;
      await isar.writeTxn(() async {
        await isar.storyRuns.put(run('old', DateTime.utc(2026, 10, 1)));
        await isar.storyRuns.put(run('new', DateTime.utc(2026, 10, 5)));
      });
      final all =
          await isar.storyRuns.where().sortByStartedAtDesc().findAll();
      expect(all.map((r) => r.runId).toList(), ['new', 'old']);
    });
  });
}
