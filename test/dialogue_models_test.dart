import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';

/// get-words-from-subtitles-improvment T12: film dialogues in the session, the
/// dialogue group link and the scene run kind (ADR-0003). Hermetic, like
/// story_models_test.dart.
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
  late CollectionStore collections;
  late StoryRunStore runs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('dialogue_models_test');
    collections = await CollectionStore.open(directory: dir.path);
    runs = await StoryRunStore.open(directory: dir.path);
  });

  tearDown(() async {
    await collections.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  FilmDialogue dialogue() => FilmDialogue()
    ..id = 'd1'
    ..lines = ['- Where is it?', '- In the attic.']
    ..wordRowIds = ['r1']
    ..scenePictureRunId = 'run-9'
    ..importId = 'imp-1'
    ..importRowIds = ['r1', 'r2']
    ..pushState = PushState.pending
    ..picturePushState = PushState.delivered
    ..hidden = true;

  void expectSameDialogue(FilmDialogue d) {
    expect(d.id, 'd1');
    expect(d.lines, ['- Where is it?', '- In the attic.']);
    expect(d.wordRowIds, ['r1']);
    expect(d.scenePictureRunId, 'run-9');
    expect(d.importId, 'imp-1');
    expect(d.importRowIds, ['r1', 'r2']);
    expect(d.pushState, PushState.pending);
    expect(d.picturePushState, PushState.delivered);
    expect(d.hidden, isTrue);
  }

  group('FilmDialogue', () {
    test('a new one has no delivery to make and is not hidden', () {
      final d = FilmDialogue();
      expect(d.pushState, PushState.none);
      expect(d.picturePushState, PushState.none);
      expect(d.hidden, isFalse);
      expect(d.scenePictureRunId, isNull);
      expect(d.importId, isNull);
    });

    test('copy and JSON keep every field', () {
      final d = dialogue();
      expectSameDialogue(d.copy());
      expectSameDialogue(FilmDialogue.fromJson(d.toJson()));
    });

    test('copy does not share the lists', () {
      final d = dialogue();
      final c = d.copy();
      c.wordRowIds.clear();
      c.importRowIds.clear();
      c.lines.clear();
      expect(d.wordRowIds, ['r1']);
      expect(d.importRowIds, ['r1', 'r2']);
      expect(d.lines, hasLength(2));
    });

    test('JSON without the delivery fields reads as nothing to deliver', () {
      final d = FilmDialogue.fromJson({'id': 'd2', 'lines': ['Hi.']});
      expect(d.lines, ['Hi.']);
      expect(d.wordRowIds, isEmpty);
      expect(d.importRowIds, isEmpty);
      expect(d.pushState, PushState.none);
      expect(d.picturePushState, PushState.none);
      expect(d.hidden, isFalse);
    });
  });

  group('Session.dialogues and WordGroup.dialogueId', () {
    test('round-trip through Isar in pager order', () async {
      final second = dialogue()..id = 'd2';
      final collection = WordCollection.create()
        ..words = [WordPair(word: 'attic', translation: 'горище', rowId: 'r1')]
        ..dialogues = [dialogue(), second]
        ..groups = [
          WordGroup()
            ..id = 'g1'
            ..name = 'Where is it?'
            ..rowIds = ['r1']
            ..dialogueId = 'd1'
        ];
      await collections.put(collection);

      final read = (await collections.byId(collection.collectionId))!;
      expect(read.dialogues.map((d) => d.id), ['d1', 'd2']);
      expectSameDialogue(read.dialogues.first);
      expect(read.groups.single.dialogueId, 'd1');
    });

    test('round-trip through JSON', () {
      final collection = WordCollection.create()
        ..dialogues = [dialogue()]
        ..groups = [WordGroup()..id = 'g1'..dialogueId = 'd1'];
      final read = WordCollection.fromJson(collection.toJson());
      expectSameDialogue(read.dialogues.single);
      expect(read.groups.single.dialogueId, 'd1');
      expect(collection.groups.single.copy().dialogueId, 'd1');
    });

    test('a session without dialogues reads with none and topic groups',
        () async {
      final collection = WordCollection.create()
        ..groups = [WordGroup()..id = 'g1'];
      await collections.put(collection);
      final read = (await collections.byId(collection.collectionId))!;
      expect(read.dialogues, isEmpty);
      expect(read.groups.single.dialogueId, isNull);

      final fromOldJson = WordCollection.fromJson({
        'sessionId': 's-old',
        'groups': [
          {'id': 'g1', 'name': 'Food'}
        ],
      });
      expect(fromOldJson.dialogues, isEmpty);
      expect(fromOldJson.groups.single.dialogueId, isNull);
    });
  });

  group('StoryRun.kind', () {
    StoryRun run(String id) => StoryRun()
      ..runId = id
      ..collectionId = 's1'
      ..groupId = 'g1'
      ..groupName = 'G'
      ..startedAt = DateTime(2026, 10, 13);

    test('a run is a story unless made a scene', () {
      expect(run('a').kind, StoryRunKind.story);
      expect(run('a').sceneText, isNull);
    });

    test('a scene run keeps its kind and dialogue text through Isar',
        () async {
      await runs.put(run('a')
        ..kind = StoryRunKind.scene
        ..sceneText = '- Where is it?\n- In the attic.');
      await runs.put(run('b'));

      final scene = (await runs.byId('a'))!;
      expect(scene.kind, StoryRunKind.scene);
      expect(scene.sceneText, '- Where is it?\n- In the attic.');
      final story = (await runs.byId('b'))!;
      expect(story.kind, StoryRunKind.story);
      expect(story.sceneText, isNull);
    });
  });
}
