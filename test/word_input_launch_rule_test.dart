import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

import 'seed_collections.dart';

/// The launch rule of collections-screen ADR-0007 (F4): after any pause the
/// pointer's collection reopens; a missing or binned pointer falls back to
/// the newest collection outside the bin; the bin is swept on open and resume.
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
    dir = Directory.systemTemp.createTempSync('launch_rule_test');
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

  Future<WordCollection> launch() =>
      container.read(wordInputNotifierProvider.future);

  Future<WordCollection> seed({
    required Duration ago,
    List<WordPair>? words,
    bool makeCurrent = true,
    DateTime? binnedAt,
    String? folderId,
  }) async {
    final at = DateTime.now().subtract(ago);
    final s = WordCollection.create()
      ..updatedAt = at
      ..lastLocalModifiedAt = at
      ..binnedAt = binnedAt
      ..folderId = folderId
      ..words = words ?? [WordPair(word: 'apple', translation: 'яблуко')];
    await seedCollection(store, s);
    if (makeCurrent) await store.setCurrentCollectionId(s.collectionId);
    return s;
  }

  Future<int> count() async => (await store.allIds()).length;

  group('F4 launch', () {
    test('empty store: a first collection is created, one blank row', () async {
      final collection = await launch();

      expect(collection.words.length, 1);
      expect(collection.words.single.isEmpty, isTrue);
      expect(await store.currentCollectionId(), collection.collectionId);
      expect(await count(), 1);
    });

    for (final ago in [
      const Duration(seconds: 5),
      const Duration(minutes: 6),
      const Duration(days: 40),
    ]) {
      test('pointer set, last edit $ago ago: it reopens, nothing new', () async {
        final prev = await seed(ago: ago);

        final collection = await launch();

        expect(collection.collectionId, prev.collectionId);
        expect(collection.words.map((w) => w.word), ['apple']);
        expect(await count(), 1);
        expect(await store.currentCollectionId(), prev.collectionId);
      });
    }

    test('the per-row extras come back with the words', () async {
      final prev = await seed(
        ago: const Duration(hours: 3),
        words: [
          WordPair(
            word: 'apple',
            translation: 'яблуко',
            hasTranslationOptions: true,
            wordMarkedFilled: true,
            translationMarkedFilled: true,
            translationOptionsJson: '{"text":"яблуко"}',
          ),
        ],
      );

      final collection = await launch();

      expect(collection.collectionId, prev.collectionId);
      final row = collection.words.single;
      expect(row.hasTranslationOptions, isTrue);
      expect(row.wordMarkedFilled, isTrue);
      expect(row.translationMarkedFilled, isTrue);
      expect(row.translationOptions?.text, 'яблуко');
    });

    test('pointer names a collection without words: it is reused', () async {
      final prev =
          await seed(ago: const Duration(days: 3), words: [WordPair()]);

      final collection = await launch();

      expect(collection.collectionId, prev.collectionId);
      expect(collection.words.length, 1);
      expect(await count(), 1);
    });

    test('no pointer: the newest collection outside the bin', () async {
      await seed(ago: const Duration(days: 2), makeCurrent: false);
      final newer = await seed(
          ago: const Duration(hours: 1),
          makeCurrent: false,
          words: [WordPair(word: 'pear', translation: 'груша')]);
      await seed(
          ago: const Duration(minutes: 1),
          makeCurrent: false,
          binnedAt: DateTime.now());

      final collection = await launch();

      expect(collection.collectionId, newer.collectionId);
      expect(await store.currentCollectionId(), newer.collectionId);
      expect(await count(), 3);
    });

    test('dangling pointer: the newest collection outside the bin', () async {
      final only = await seed(ago: const Duration(hours: 1), makeCurrent: false);
      await store.setCurrentCollectionId('gone');

      final collection = await launch();

      expect(collection.collectionId, only.collectionId);
      expect(await store.currentCollectionId(), only.collectionId);
    });

    test('pointer binned directly: falls back, the binned one stays binned',
        () async {
      final ok = await seed(ago: const Duration(days: 1), makeCurrent: false);
      final binned = await seed(
          ago: const Duration(minutes: 1), binnedAt: DateTime.now());

      final collection = await launch();

      expect(collection.collectionId, ok.collectionId);
      expect(await store.currentCollectionId(), ok.collectionId);
      expect((await store.byId(binned.collectionId))!.binnedAt, isNotNull);
    });

    test('pointer inside a binned folder: falls back', () async {
      final ok = await seed(ago: const Duration(days: 1), makeCurrent: false);
      final folder = (await store.createFolder(name: 'F')).folder!;
      final inside = await seed(
          ago: const Duration(minutes: 1),
          makeCurrent: false,
          folderId: folder.folderId);
      await store.bin(folder.folderId);
      await store.setCurrentCollectionId(inside.collectionId);

      final collection = await launch();

      expect(collection.collectionId, ok.collectionId);
    });

    test('pointer gone and everything else binned: a new collection',
        () async {
      final binned = await seed(
          ago: const Duration(minutes: 1), binnedAt: DateTime.now());

      final collection = await launch();

      expect(collection.collectionId, isNot(binned.collectionId));
      expect(collection.words.single.isEmpty, isTrue);
      expect(await store.currentCollectionId(), collection.collectionId);
      expect(await count(), 2);
    });

    test('the bin is swept on open: a 31-day-old item goes, a fresh one stays',
        () async {
      await seed(ago: const Duration(hours: 1));
      final old = await seed(
          ago: const Duration(days: 40),
          makeCurrent: false,
          binnedAt: DateTime.now().subtract(const Duration(days: 31)));
      final fresh = await seed(
          ago: const Duration(days: 40),
          makeCurrent: false,
          binnedAt: DateTime.now().subtract(const Duration(days: 5)));

      await launch();

      expect(await store.byId(old.collectionId), isNull);
      expect(await store.byId(fresh.collectionId), isNotNull);
    });
  });

  group('F4 resume', () {
    test('resume sweeps the bin', () async {
      await seed(ago: const Duration(hours: 1));
      final old = await seed(
          ago: const Duration(days: 40),
          makeCurrent: false,
          binnedAt: DateTime.now().subtract(const Duration(days: 29)));
      await launch();
      // Becomes 31 days old while the app sleeps.
      final isar = Isar.getInstance('vocab')!;
      await isar.writeTxn(() async {
        final c = await isar.wordCollections
            .filter()
            .collectionIdEqualTo(old.collectionId)
            .findFirst();
        await isar.wordCollections.put(
            c!..binnedAt = DateTime.now().subtract(const Duration(days: 31)));
      });

      await container.read(wordInputNotifierProvider.notifier).resume();

      expect(await store.byId(old.collectionId), isNull);
    });

    test('resume keeps the current collection and makes no new one', () async {
      final prev = await seed(ago: const Duration(days: 2));
      await launch();

      await container.read(wordInputNotifierProvider.notifier).resume();

      expect(container.read(wordInputNotifierProvider).value!.collectionId,
          prev.collectionId);
      expect(await count(), 1);
    });

    test('resume re-checks the pointer: a collection binned meanwhile falls back',
        () async {
      final ok = await seed(ago: const Duration(days: 1), makeCurrent: false);
      final cur = await seed(ago: const Duration(minutes: 1));
      await launch();
      // Another path moved it to the bin while the app was paused.
      final isar = Isar.getInstance('vocab')!;
      await isar.writeTxn(() async {
        final c = await isar.wordCollections
            .filter()
            .collectionIdEqualTo(cur.collectionId)
            .findFirst();
        await isar.wordCollections.put(c!..binnedAt = DateTime.now());
      });

      await container.read(wordInputNotifierProvider.notifier).resume();

      expect(container.read(wordInputNotifierProvider).value!.collectionId,
          ok.collectionId);
      expect(await store.currentCollectionId(), ok.collectionId);
    });
  });

  group('legacy keys', () {
    const legacy = [
      'switched_session_id',
      'switched_at',
      'seen_session_id',
      'seen_at',
    ];

    test('switched_* and seen_* are removed at startup and never written',
        () async {
      SharedPreferences.setMockInitialValues({
        for (final k in legacy) k: 'x',
        'current_session_id': 'keep',
      });
      final again = await CollectionStore.open(directory: dir.path);
      final prefs = await SharedPreferences.getInstance();
      for (final k in legacy) {
        expect(prefs.containsKey(k), isFalse, reason: k);
      }
      expect(prefs.getString('current_session_id'), 'keep');

      final c = container.read(wordInputNotifierProvider.notifier);
      await seed(ago: const Duration(minutes: 1));
      await c.future;
      await c.resume();
      await prefs.reload();
      for (final k in legacy) {
        expect(prefs.containsKey(k), isFalse, reason: k);
      }
      expect(again, isNotNull);
    });
  });
}
