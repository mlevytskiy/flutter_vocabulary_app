@Tags(['smoke'])
library;

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

/// definition-mode T10: the notifier keeps definitions through every row
/// operation (spec AC-11, AC-13).
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
    dir = Directory.systemTemp.createTempSync('word_input_notifier_test');
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

  Future<WordInputNotifier> seeded(List<WordPair> pairs) async {
    await container.read(wordInputNotifierProvider.future);
    final notifier = container.read(wordInputNotifierProvider.notifier);
    notifier.setPairs(pairs);
    return notifier;
  }

  List<WordPair> words() =>
      container.read(wordInputNotifierProvider).value!.words;

  test('updating the translation keeps the definition and its senses',
      () async {
    final notifier = await seeded([
      WordPair(
        word: 'tenacious',
        definition: 'persistent',
        definitionOptionsJson: '{"senses":["persistent","retentive"]}',
        definitionMarkedFilled: true,
      ),
    ]);

    notifier.updateAt(0, translation: 'наполегливий');

    expect(words()[0].translation, 'наполегливий');
    expect(words()[0].definition, 'persistent');
    expect(words()[0].definitionOptionsJson,
        '{"senses":["persistent","retentive"]}');
    expect(words()[0].definitionMarkedFilled, isTrue);
  });

  test('definition, senses and mark can be set and cleared', () async {
    final notifier = await seeded([WordPair(word: 'claim')]);

    notifier.updateAt(0,
        definition: 'to ask for as a right',
        definitionOptionsJson: '{"senses":["to ask for as a right"]}',
        definitionMarkedFilled: true);
    expect(words()[0].definition, 'to ask for as a right');
    expect(words()[0].definitionMarkedFilled, isTrue);

    notifier.updateAt(0, clearDefinitionOptions: true);
    expect(words()[0].definitionOptionsJson, isNull);
    expect(words()[0].definition, 'to ask for as a right');
  });

  test('reorder and remove keep definitions with their words', () async {
    final notifier = await seeded([
      WordPair(word: 'a', definition: 'def a'),
      WordPair(word: 'b', definition: 'def b'),
      WordPair(word: 'c', definition: 'def c'),
    ]);

    notifier.reorder(0, 2);
    expect(words().map((w) => '${w.word}:${w.definition}'),
        ['b:def b', 'c:def c', 'a:def a']);

    notifier.removeAt(0);
    expect(words().map((w) => '${w.word}:${w.definition}'),
        ['c:def c', 'a:def a']);
  });

  test('definitions are saved and come back after a restart', () async {
    final notifier = await seeded([
      WordPair(word: 'curse', definition: 'a prayer for harm'),
    ]);
    notifier.updateAt(0, translation: 'прокляття');
    await notifier.flush();

    final collectionId =
        container.read(wordInputNotifierProvider).value!.collectionId;
    final back = await store.byId(collectionId);
    expect(back!.words[0].definition, 'a prayer for harm');
    expect(back.words[0].translation, 'прокляття');
  });

  // Pre-existing bug found by definition-mode T10: Isar hands back a stored
  // session's words as a fixed-length list, so the first row the screen adds
  // to a reused (warm) session threw "Cannot add to a fixed-length list".
  test('a reused stored session can grow', () async {
    final warm = WordCollection.create()
      ..words = [WordPair(word: 'apple', translation: 'яблуко')];
    await seedCollection(store, warm);
    await store.setCurrentCollectionId(warm.collectionId);

    final collection = await container.read(wordInputNotifierProvider.future);
    expect(collection.collectionId, warm.collectionId);

    container.read(wordInputNotifierProvider.notifier).addAll([WordPair()]);
    expect(words(), hasLength(2));
  });

  // good-looking-web T18 (ADR-0008): the id and token a publish returns are
  // kept, so the next publish overwrites the same link.
  test('markShared stores the published id and edit token', () async {
    final notifier = await seeded([WordPair(word: 'tea', translation: 'чай')]);
    await notifier.flush();
    final collection = container.read(wordInputNotifierProvider).value!;
    final touched = collection.lastLocalModifiedAt;

    await notifier.markShared(publishedId: 'pub-1', editToken: 'tok-1');
    await notifier.markShared(publishedId: 'pub-1', editToken: 'tok-2');

    final stored = await store.byId(collection.collectionId);
    expect(stored!.isShared, isTrue);
    expect(stored.publishedId, 'pub-1');
    expect(stored.editToken, 'tok-2');
    expect(stored.lastLocalModifiedAt, touched); // not a content change
  });

  // edit-session-from-history T2 (ADR-0001, AC-03, AC-07, AC-08).
  group('switchTo', () {
    Future<WordCollection> past(String word) async {
      final at = DateTime(2026, 9, 1, 12);
      final s = WordCollection.create()
        ..updatedAt = at
        ..lastLocalModifiedAt = at
        ..words = [WordPair(word: word, translation: word)];
      await seedCollection(store, s);
      return s;
    }

    /// A fresh current collection to leave, as a launch on an empty store makes.
    Future<void> leftCurrent() async {
      final left = await store.create();
      await store.setCurrentCollectionId(left.collectionId);
    }

    test('makes the picked session current without stamping its edit times',
        () async {
      final picked = await past('tea');
      await container.read(wordInputNotifierProvider.future);
      final notifier = container.read(wordInputNotifierProvider.notifier);

      expect(await notifier.switchTo(picked.collectionId), isTrue);

      final now = container.read(wordInputNotifierProvider).value!;
      expect(now.collectionId, picked.collectionId);
      expect(now.words.map((w) => w.word), ['tea']);
      expect(now.lastLocalModifiedAt, DateTime(2026, 9, 1, 12));
      expect(now.updatedAt, DateTime(2026, 9, 1, 12));
      expect(await store.currentCollectionId(), picked.collectionId);
      final stored = await store.byId(picked.collectionId);
      expect(stored!.lastLocalModifiedAt, DateTime(2026, 9, 1, 12));

      // The picked session can grow like any other.
      notifier.addAll([WordPair()]);
      expect(words(), hasLength(2));
    });

    test('a word typed just before the switch is saved in the left session',
        () async {
      final picked = await past('tea');
      await leftCurrent();
      final notifier = await seeded([WordPair(word: 'coffee')]);
      final leftId =
          container.read(wordInputNotifierProvider).value!.collectionId;
      notifier.updateAt(0, translation: 'кава');

      await notifier.switchTo(picked.collectionId);

      final left = await store.byId(leftId);
      expect(left, isNotNull);
      expect(left!.words.single.translation, 'кава');
      // ...and nothing written later lands in it.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect((await store.byId(picked.collectionId))!.lastLocalModifiedAt,
          DateTime(2026, 9, 1, 12));
    });

    test('an empty left session is deleted', () async {
      final picked = await past('tea');
      await leftCurrent();
      final left = await container.read(wordInputNotifierProvider.future);
      expect(left.isEmpty, isTrue);

      await container
          .read(wordInputNotifierProvider.notifier)
          .switchTo(picked.collectionId);

      expect(await store.byId(left.collectionId), isNull);
    });

    test('an unknown id returns false and changes nothing', () async {
      final notifier = await seeded([WordPair(word: 'coffee')]);
      await notifier.flush();
      final current = container.read(wordInputNotifierProvider).value!;
      final collectionsBefore = (await store.nonEmpty()).length;

      expect(await notifier.switchTo('gone'), isFalse);

      final after = container.read(wordInputNotifierProvider).value!;
      expect(after.collectionId, current.collectionId);
      expect(after.words.single.word, 'coffee');
      expect(await store.currentCollectionId(), current.collectionId);
      expect((await store.nonEmpty()).length, collectionsBefore);
    });
  });
}
