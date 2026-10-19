import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';
import 'package:flutter_vocabulary_app/router/start_location.dart';

import 'seed_collections.dart';

/// start-screen (owner, 2026-10-18): Words after a short break or with
/// nothing to pick from, Collections otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final words = const WordsRoute().location;
  final collections = const CollectionsRoute().location;
  final now = DateTime(2026, 10, 18, 12);

  group('pick', () {
    test('back within 5 minutes opens Words', () {
      expect(
          StartLocation.pick(
              now: now,
              leftAt: now.subtract(const Duration(minutes: 4, seconds: 59)),
              onlyOneEmpty: false),
          words);
    });

    test('back after 5 minutes or more opens Collections', () {
      expect(
          StartLocation.pick(
              now: now,
              leftAt: now.subtract(const Duration(minutes: 5)),
              onlyOneEmpty: false),
          collections);
    });

    test('never left before opens Collections', () {
      expect(StartLocation.pick(now: now, leftAt: null, onlyOneEmpty: false),
          collections);
    });

    test('only one empty collection always opens Words', () {
      expect(StartLocation.pick(now: now, leftAt: null, onlyOneEmpty: true),
          words);
      expect(
          StartLocation.pick(
              now: now,
              leftAt: now.subtract(const Duration(days: 3)),
              onlyOneEmpty: true),
          words);
    });
  });

  group('onlyOneEmpty', () {
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('start_location_test');
      store = await CollectionStore.open(directory: dir.path);
    });

    tearDown(() async {
      await store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    Future<bool> check() => CollectionStore.onlyOneEmpty(directory: dir.path);

    test('a new user: no collection', () async {
      expect(await check(), isTrue);
    });

    test('one collection with no words', () async {
      await store.create();
      expect(await check(), isTrue);
    });

    test('one collection with a word', () async {
      await seedCollection(
          store,
          WordCollection.create()
            ..words = [WordPair(word: 'apple', translation: 'яблуко')]);
      expect(await check(), isFalse);
    });

    test('two empty collections', () async {
      await store.create();
      await store.create();
      expect(await check(), isFalse);
    });

    test('a binned collection does not count', () async {
      await store.create();
      final binned = await store.create();
      await store.bin(binned.collectionId);
      expect(await check(), isTrue);
    });
  });
}
