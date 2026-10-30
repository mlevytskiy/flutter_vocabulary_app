import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';

/// AC-04 / ADR-0002: `test/fixtures/pre_rename_vocab/vocab.isar` was written
/// by the build from before Session was renamed to WordCollection. The
/// renamed build must open it through the pinned stored names (`Session`,
/// `sessionId`).

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Isar writes to the file it opens, so open a copy.
    dir = Directory.systemTemp.createTempSync('pre_rename_fixture_test');
    File('$fixture/vocab.isar').copySync('${dir.path}/vocab.isar');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
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
