@Tags(['smoke'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

import 'seed_collections.dart';

/// Hermetic: a throwaway Isar directory per test, no network, no device.
/// The first run downloads the native Isar library into the pub cache — see
/// `docs/tasks/README.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // TestWidgetsFlutterBinding installs HttpOverrides that turn every request
    // into a 400, which is exactly what the one-off IsarCore download needs to
    // get past. Lift them for the download and put them straight back.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('collection_store_test');
    store = await CollectionStore.open(directory: dir.path);
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  TranslationResult twoGroups() => const TranslationResult(
        text: 'яблуко',
        alternatives: ['яблуко', 'яблучко'],
        detectedSourceLanguage: 'en',
        dictionary: [
          DictionaryEntry(
            pos: 'noun',
            words: [
              DictionaryWord(word: 'яблуко', backTranslations: ['apple']),
              DictionaryWord(word: 'яблучко', backTranslations: ['apple']),
            ],
          ),
          DictionaryEntry(
            pos: 'verb',
            words: [DictionaryWord(word: 'яблучити')],
          ),
        ],
      );

  group('SessionStore', () {
    // AC-2
    test('round-trips words, their characters and all four extras', () async {
      final options = twoGroups();
      final collection = WordCollection.create()
        ..words = [
          WordPair(word: 'with\ttab', translation: 'з\tтабом'),
          WordPair(word: 'multi\nline', translation: 'багато\nрядків'),
          WordPair(
            word: 'apple',
            translation: 'яблуко',
            hasTranslationOptions: true,
            wordMarkedFilled: true,
            translationMarkedFilled: true,
          )..translationOptions = options,
        ];

      await seedCollection(store, collection);
      final back = await store.byId(collection.collectionId);

      expect(back, isNotNull);
      expect(back!.words.map((w) => w.word).toList(),
          ['with\ttab', 'multi\nline', 'apple']);
      expect(back.words.map((w) => w.translation).toList(),
          ['з\tтабом', 'багато\nрядків', 'яблуко']);

      final restored = back.words[2];
      expect(restored.hasTranslationOptions, isTrue);
      expect(restored.wordMarkedFilled, isTrue);
      expect(restored.translationMarkedFilled, isTrue);

      final popup = restored.translationOptions;
      expect(popup, isNotNull);
      expect(popup!.text, options.text);
      expect(popup.alternatives, options.alternatives);
      expect(popup.dictionary.length, options.dictionary.length);
      for (var i = 0; i < popup.dictionary.length; i++) {
        expect(popup.dictionary[i].pos, options.dictionary[i].pos);
        expect(popup.dictionary[i].wordList, options.dictionary[i].wordList);
        expect(popup.dictionary[i].words.first.backTranslations,
            options.dictionary[i].words.first.backTranslations);
      }
    });

    // AC-3
    test('does not persist the trailing blank row', () async {
      final collection = WordCollection.create()
        ..words = [
          WordPair(word: 'a', translation: 'а'),
          WordPair(word: 'b', translation: 'б'),
          WordPair(),
        ];

      await seedCollection(store, collection);

      expect((await store.byId(collection.collectionId))!.words.length, 2);
      // ...and the caller's own list is left alone.
      expect(collection.words.length, 3);
    });

    // definition-mode AC-13: definitions survive a restart; a definition-only
    // row is not a blank row.
    test('round-trips definitions and keeps definition-only rows', () async {
      final collection = WordCollection.create()
        ..words = [
          WordPair(
            word: 'tenacious',
            definition: 'persistent in maintaining something valued',
            definitionOptionsJson: '{"senses":["a"]}',
            definitionMarkedFilled: true,
          ),
          WordPair(word: 'claim', translation: 'заява'),
        ];

      await seedCollection(store, collection);
      final back = (await store.byId(collection.collectionId))!;

      expect(back.words.length, 2);
      expect(back.words[0].definition,
          'persistent in maintaining something valued');
      expect(back.words[0].definitionOptionsJson, '{"senses":["a"]}');
      expect(back.words[0].definitionMarkedFilled, isTrue);
      expect(back.words[1].definition, '');
    });

    // AC-4
    test('an empty store answers with null / [] and never throws', () async {
      expect(await store.newest(), isNull);
      expect(await store.nonEmpty(), isEmpty);
      expect(await store.byId('nope'), isNull);
      expect(await store.currentCollectionId(), isNull);
    });

    // AC-5
    test('nonEmpty() skips all-blank sessions; watchHistory() emits on write',
        () async {
      final blank = WordCollection.create()..words = [WordPair()];
      await seedCollection(store, blank);
      expect(await store.nonEmpty(), isEmpty);

      final emissions = <List<WordCollection>>[];
      final sub = store.watchHistory().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.length, 1, reason: 'fireImmediately');
      expect(emissions.first, isEmpty);

      final filled = WordCollection.create()
        ..words = [WordPair(word: 'a', translation: 'а')];
      await seedCollection(store, filled);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions.length, greaterThan(1));
      expect(emissions.last.map((s) => s.collectionId), [filled.collectionId]);
      await sub.cancel();
    });

    test('newest() is the session this device touched last', () async {
      final older = WordCollection.create()
        ..words = [WordPair(word: 'old', translation: 'старе')]
        ..lastLocalModifiedAt =
            DateTime.now().subtract(const Duration(hours: 2));
      final newer = WordCollection.create()
        ..words = [WordPair(word: 'new', translation: 'нове')];
      await seedCollection(store, older);
      await seedCollection(store, newer);

      expect((await store.newest())!.collectionId, newer.collectionId);
      expect((await store.nonEmpty()).map((s) => s.collectionId).toList(),
          [newer.collectionId, older.collectionId]);
    });

    test('put upserts on sessionId instead of piling up rows', () async {
      final collection = WordCollection.create()
        ..words = [WordPair(word: 'a', translation: 'а')];
      await seedCollection(store, collection);
      collection.words.add(WordPair(word: 'b', translation: 'б'));
      await store.put(collection);

      expect((await store.nonEmpty()).length, 1);
      expect((await store.byId(collection.collectionId))!.words.length, 2);
    });

    test('delete removes the session; the pointer round-trips', () async {
      final collection = WordCollection.create()
        ..words = [WordPair(word: 'a', translation: 'а')];
      await seedCollection(store, collection);
      await store.setCurrentCollectionId(collection.collectionId);
      expect(await store.currentCollectionId(), collection.collectionId);

      await store.delete(collection.collectionId);
      expect(await store.byId(collection.collectionId), isNull);
      expect(await store.nonEmpty(), isEmpty);
    });

    // edit-session-from-history T1 (ADR-0002, AC-09): the pick record is
    // answered only for the session it names.
    test('switchedAt answers only for the session that was picked', () async {
      final at = DateTime(2026, 9, 29, 10, 30, 15);
      await store.setSwitched('A', at);

      expect(await store.switchedAt('A'), at);
      expect(await store.switchedAt('B'), isNull);
    });

    test('the pick record survives reopening the store', () async {
      final at = DateTime(2026, 9, 29, 10, 30, 15);
      await store.setSwitched('A', at);
      await store.close();
      store = await CollectionStore.open(directory: dir.path);

      expect(await store.switchedAt('A'), at);
    });

    test('a missing or corrupt pick record reads as null', () async {
      expect(await store.switchedAt('A'), isNull);

      await store.setSwitched('A', DateTime(2026, 9, 29));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('switched_at', 'not a time');

      expect(await store.switchedAt('A'), isNull);
    });
  });

  // collections-screen T5 (ADR-0003, data-model.md put() contract): only
  // create() inserts; put() keeps the stored filing and may only raise keep.
  group('filing', () {
    Isar isar() => Isar.getInstance('vocab')!;

    test('create() inserts an unkept collection named after its moment',
        () async {
      final before = DateTime.now();
      final made = await store.create();
      final stored = await store.byId(made.collectionId);

      expect(stored, isNotNull);
      expect(stored!.keep, isFalse);
      expect(stored.folderId, isNull);
      expect(stored.binnedAt, isNull);
      expect(stored.binnedFromFolderId, isNull);
      expect(stored.name, made.name);
      expect(
          stored.name,
          anyOf(defaultCollectionName(before),
              defaultCollectionName(DateTime.now())));
    });

    test('create(keep: true, folderId:) inserts a kept collection there',
        () async {
      final made = await store.create(folderId: 'folder-1', keep: true);
      final stored = await store.byId(made.collectionId);

      expect(stored!.keep, isTrue);
      expect(stored.folderId, 'folder-1');
    });

    test('create() puts the new collection at the end of its level', () async {
      await isar()
          .writeTxn(() => isar().collectionFolders.put(CollectionFolder()
            ..folderId = 'folder-1'
            ..name = 'English course'
            ..order = 0));
      final a = await store.create();
      final b = await store.create();
      final inside = await store.create(folderId: 'folder-1');

      expect((await store.byId(a.collectionId))!.order, 1);
      expect((await store.byId(b.collectionId))!.order, 2);
      expect((await store.byId(inside.collectionId))!.order, 0);
    });

    test('put() copies the six filing fields from the stored record', () async {
      final made = await store.create(folderId: 'folder-1', keep: true);
      final binned = DateTime(2026, 10, 1, 9);
      await isar().writeTxn(() async {
        final s = (await isar()
            .wordCollections
            .filter()
            .collectionIdEqualTo(made.collectionId)
            .findFirst())!;
        await isar().wordCollections.put(s
          ..name = 'Lesson 3'
          ..order = 4
          ..binnedAt = binned
          ..binnedFromFolderId = 'folder-2');
      });

      final stale = WordCollection()
        ..collectionId = made.collectionId
        ..updatedAt = made.updatedAt
        ..lastLocalModifiedAt = made.lastLocalModifiedAt
        ..name = 'stale'
        ..folderId = null
        ..order = 0
        ..binnedAt = null
        ..binnedFromFolderId = null
        ..keep = false
        ..tags = ['a'];
      await store.put(stale);
      final stored = (await store.byId(made.collectionId))!;

      expect(stored.tags, ['a']);
      expect(stored.name, 'Lesson 3');
      expect(stored.folderId, 'folder-1');
      expect(stored.order, 4);
      expect(stored.binnedAt, binned);
      expect(stored.binnedFromFolderId, 'folder-2');
      expect(stored.keep, isTrue);
    });

    test('put() raises keep only when the copy has a word', () async {
      final made = await store.create();
      made.words = [WordPair()];
      await store.put(made);
      expect((await store.byId(made.collectionId))!.keep, isFalse);

      made.words = [WordPair(word: 'apple'), WordPair()];
      await store.put(made);
      expect((await store.byId(made.collectionId))!.keep, isTrue);
    });

    test('put() never lowers keep', () async {
      final made = await store.create(keep: true);
      await store.put(made..keep = false);

      expect((await store.byId(made.collectionId))!.keep, isTrue);
    });

    test('put() writes nothing when no record with that id exists', () async {
      final ghost = WordCollection.create()
        ..words = [WordPair(word: 'apple', translation: 'яблуко')];
      await store.put(ghost);

      expect(await store.byId(ghost.collectionId), isNull);
      expect(await isar().wordCollections.count(), 0);
    });

    test('a folder round-trips through the store\'s Isar', () async {
      await isar()
          .writeTxn(() => isar().collectionFolders.put(CollectionFolder()
            ..folderId = 'folder-1'
            ..name = 'English course'
            ..parentId = null
            ..order = 2));
      final f = await isar()
          .collectionFolders
          .filter()
          .folderIdEqualTo('folder-1')
          .findFirst();

      expect(f!.name, 'English course');
      expect(f.parentId, isNull);
      expect(f.order, 2);
      expect(f.binnedAt, isNull);
      expect(f.binnedFromFolderId, isNull);
    });
  });
}
