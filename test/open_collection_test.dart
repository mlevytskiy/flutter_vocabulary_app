import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

import 'seed_collections.dart';

/// collections-screen T12 (AC-09, AC-10, AC-12, AC-18, AC-19): open(id) and
/// newCollection(folderId) with the leave rule.
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
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('open_collection_test');
    store = await CollectionStore.open(directory: dir.path);
    container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<WordCollection> past(String word) async {
    final at = DateTime(2026, 9, 1, 12);
    final s = WordCollection.create()
      ..updatedAt = at
      ..lastLocalModifiedAt = at
      ..words = [WordPair(word: word, translation: word)];
    await seedCollection(store, s);
    return s;
  }

  /// The current collection to leave: empty and untouched, as a launch makes.
  Future<WordCollection> current() async {
    final left = await store.create();
    await store.setCurrentCollectionId(left.collectionId);
    await container.read(wordInputNotifierProvider.future);
    return left;
  }

  WordInputNotifier notifier() =>
      container.read(wordInputNotifierProvider.notifier);
  WordCollection shown() => container.read(wordInputNotifierProvider).value!;

  group('open', () {
    test('shows the opened collection and sets the pointer', () async {
      final picked = await past('tea');
      await current();

      await notifier().open(picked.collectionId);

      expect(shown().collectionId, picked.collectionId);
      expect(shown().words.single.word, 'tea');
      expect(await store.currentCollectionId(), picked.collectionId);
      expect(shown().lastLocalModifiedAt, DateTime(2026, 9, 1, 12));
    });

    test('flushes the autosave of the left collection', () async {
      final picked = await past('tea');
      final left = await current();
      notifier().setPairs([WordPair(word: 'coffee')]);

      await notifier().open(picked.collectionId);

      final stored = await store.byId(left.collectionId);
      expect(stored!.words.single.word, 'coffee');
    });

    test('a never-touched empty left collection is erased at once', () async {
      final picked = await past('tea');
      final left = await current();

      await notifier().open(picked.collectionId);

      expect(await store.byId(left.collectionId), isNull);
    });

    test('an empty collection made with New collection is kept', () async {
      final picked = await past('tea');
      await current();
      await notifier().newCollection(null);
      final made = shown().collectionId;

      await notifier().open(picked.collectionId);

      expect(await store.byId(made), isNotNull);
    });

    test('a renamed empty left collection is kept', () async {
      final picked = await past('tea');
      final left = await current();
      await store.rename(left.collectionId, 'Travel');

      await notifier().open(picked.collectionId);

      expect(await store.byId(left.collectionId), isNotNull);
    });

    test('a left collection with tags or source notes is kept', () async {
      final picked = await past('tea');
      final left = await current();
      shown().tags = ['trip'];
      notifier().setPairs([WordPair()]);
      await notifier().flush();
      final stored = (await store.byId(left.collectionId))!;
      expect(stored.tags, ['trip']);

      await notifier().open(picked.collectionId);

      expect(await store.byId(left.collectionId), isNotNull);
    });

    test('a left collection with a source description is kept', () async {
      final picked = await past('tea');
      final left = await current();
      shown().sources = [
        SessionSource()
          ..id = 's1'
          ..description = 'note'
      ];
      notifier().setPairs([WordPair()]);
      await notifier().flush();

      await notifier().open(picked.collectionId);

      expect(await store.byId(left.collectionId), isNotNull);
    });

    test('a left collection with words is kept', () async {
      final picked = await past('tea');
      final left = await current();
      notifier().setPairs([WordPair(word: 'coffee')]);

      await notifier().open(picked.collectionId);

      expect(await store.byId(left.collectionId), isNotNull);
    });

    test('an erased-on-leave collection is in neither History nor the bin',
        () async {
      final picked = await past('tea');
      final left = await current();

      await notifier().open(picked.collectionId);

      expect((await store.nonEmpty()).map((c) => c.collectionId),
          isNot(contains(left.collectionId)));
      expect(await store.byId(left.collectionId), isNull);
    });

    test('open of the current collection changes nothing', () async {
      final left = await current();
      final before = shown();

      await notifier().open(left.collectionId);

      expect(shown(), same(before));
      expect(await store.byId(left.collectionId), isNotNull);
    });

    test('an unknown id changes nothing', () async {
      final left = await current();

      await notifier().open('gone');

      expect(shown().collectionId, left.collectionId);
    });
  });

  group('newCollection', () {
    test('makes a kept, empty, date-named collection current', () async {
      final left = await current();

      await notifier().newCollection(null);

      final now = shown();
      expect(now.collectionId, isNot(left.collectionId));
      expect(now.keep, isTrue);
      expect(now.isEmpty, isTrue);
      expect(now.name, defaultCollectionName(now.updatedAt));
      expect(await store.currentCollectionId(), now.collectionId);
      expect((await store.byId(now.collectionId))!.keep, isTrue);
      expect(await store.byId(left.collectionId), isNull);
    });

    test('goes to the end of the given folder', () async {
      await current();
      final folder = (await store.createFolder(name: 'Trips')).folder!;
      final first =
          await store.create(folderId: folder.folderId, keep: true);

      await notifier().newCollection(folder.folderId);

      final now = shown();
      expect(now.folderId, folder.folderId);
      expect(now.order, greaterThan(first.order));
    });

    test('flushes the left collection first', () async {
      final left = await current();
      notifier().setPairs([WordPair(word: 'coffee')]);

      await notifier().newCollection(null);

      expect((await store.byId(left.collectionId))!.words.single.word,
          'coffee');
    });
  });
}
