import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

/// word-context T4, AC-03: the one-time origin backfill of
/// `CollectionStore.open`.
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
  late Isar isar;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('word_origin_store_test');
    isar = await Isar.open(
        [WordCollectionSchema, StoryRunSchema, CollectionFolderSchema],
        directory: dir.path, name: 'vocab');
  });

  tearDown(() async {
    if (isar.isOpen) await isar.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  WordPair row(String w, [String? sourceId]) =>
      WordPair(word: w, translation: '$w-uk', sourceId: sourceId)
        ..rowId = 'row-$w';

  SessionSource src(String id, SourceKind kind, {String? name}) =>
      SessionSource()
        ..id = id
        ..kind = kind
        ..name = name;

  Future<WordCollection> read() async =>
      (await isar.wordCollections.where().findFirst())!;

  test('mixed old rows get the right types once; the second load is a no-op',
      () async {
    final c = WordCollection()
      ..collectionId = '1'
      ..name = 'Old'
      ..updatedAt = DateTime(2026, 1, 1)
      ..lastLocalModifiedAt = DateTime(2026, 1, 1)
      ..sources = [
        src('p', SourceKind.photo),
        src('s', SourceKind.set, name: 'Set'),
        src('m', SourceKind.subtitles, name: 'Show.S02E05.srt'),
      ]
      ..words = [
        row('typed'),
        row('photo', 'p'),
        row('set', 's'),
        row('film', 'm'),
        row('gone', 'zzz'),
      ];
    await isar.writeTxn(() => isar.wordCollections.put(c));

    await CollectionStore.open(directory: dir.path);
    final r = await read();
    final types = [for (final w in r.words) w.origin.typeOfSource];
    expect(types, [
      SourceType.manuallyEntered,
      SourceType.image,
      SourceType.set,
      SourceType.movie,
      SourceType.manuallyEntered,
    ]);
    expect(r.words[3].origin.movieName, 'Show.S02E05.srt');
    expect(r.words[3].origin.season, 2);
    expect(r.words[3].origin.episode, 5);
    for (final w in r.words) {
      expect(w.origin.wasTranslationEditByUser, isFalse);
      expect(w.origin.wasDescriptionEditByUser, isFalse);
    }

    // A learner's later change survives a second load.
    r.words[1].origin.typeOfSource = SourceType.manuallyEntered;
    r.words[1].sourceId = null;
    r.words[2].origin.wasTranslationEditByUser = true;
    await isar.writeTxn(() => isar.wordCollections.put(r));
    final before = r.toJson().toString();

    await CollectionStore.open(directory: dir.path);
    expect((await read()).toJson().toString(), before);
  });
}
