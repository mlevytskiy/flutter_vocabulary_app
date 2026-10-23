import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/words/collection_tag_line.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words/words_screen.dart';

import 'seed_collections.dart';

/// collection-tags T8 (ADR-0004, sad §8 Notifier adoption, Flows 1, 4, 7;
/// AC-05, 06, 15, 16, 18, 28, 29, 33): details and tag edits go through the
/// store and the notifier adopts the stored values, so an autosave never
/// writes an older copy back.
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
  late WordCollection seeded;

  final old = DateTime(2026, 10, 1, 9);

  Future<void> open({bool withWords = true}) async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('collection_tags_notifier_test');
    store = await CollectionStore.open(directory: dir.path);
    seeded = WordCollection.create()
      ..updatedAt = old
      ..lastLocalModifiedAt = old
      ..name = 'Kitchen'
      ..words =
          withWords ? [WordPair(word: 'apple', translation: 'яблуко')] : []
      ..sources = [
        SessionSource()
          ..id = 'p1'
          ..fileName = 'p1.jpg',
      ];
    await seedCollection(store, seeded);
    await store.setCurrentCollectionId(seeded.collectionId);
    container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
    await container.read(wordsProvider.future);
  }

  Future<void> close() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  WordsNotifier notifier() =>
      container.read(wordsProvider.notifier);
  WordCollection shown() => container.read(wordsProvider).value!;
  Future<WordCollection> stored() async =>
      (await store.byId(seeded.collectionId))!;

  /// An ordinary edit followed by the autosave write.
  Future<void> autosave() async {
    notifier().setPairs([WordPair(word: 'pear', translation: 'груша')]);
    await notifier().flush();
  }

  group('with the real notifier and store', () {
    setUp(open);
    tearDown(close);

    test('a collection tag save shows at once and an autosave keeps it',
        () async {
      expect(await notifier().setCollectionTags(TagKind.topic, ['travel']),
          isTrue);
      expect(shown().topicTags, ['travel']);
      await autosave();
      expect(shown().topicTags, ['travel']);
      expect((await stored()).topicTags, ['travel']);
      expect((await stored()).words.single.word, 'pear');
    });

    test('details save adopts the description, name and tags', () async {
      expect(
          await notifier().saveDetails(
              name: 'Pantry',
              description: 'From the podcast',
              origin: ['Quizlet']),
          isTrue);
      expect(shown().name, 'Pantry');
      expect(shown().description, 'From the podcast');
      expect(shown().originTags, ['Quizlet']);
      await autosave();
      expect((await stored()).description, 'From the podcast');
      expect(await notifier().saveDetails(name: ''), isFalse,
          reason: 'a refused name');
    });

    test('a source tag survives the autosave after updateSourceNote', () async {
      final refused =
          await notifier().updateSourceNote('p1', topic: ['food'], title: 'T');
      expect(refused, isEmpty);
      expect(shown().sources.single.topicTags, ['food']);
      expect(shown().topicTags, ['food'], reason: 'copied up');
      await autosave();
      final back = await stored();
      expect(back.sources.single.topicTags, ['food']);
      expect(back.sources.single.title, 'T');
      expect(back.topicTags, ['food']);
    });

    test('the edited time is not rolled back by markShared or updateDialogues',
        () async {
      await notifier().saveDetails(description: 'x');
      final edited = (await stored()).updatedAt;
      expect(edited.isAfter(old), isTrue);
      expect(shown().updatedAt, edited);
      await notifier().markShared(publishedId: 'pub', editToken: 'tok');
      await notifier().updateDialogues((d) => d);
      final back = await stored();
      expect(back.updatedAt, edited);
      expect(back.lastLocalModifiedAt, back.lastLocalModifiedAt);
      expect(back.lastLocalModifiedAt.isBefore(edited), isFalse);
      expect(shown().updatedAt, edited);
      expect(back.description, 'x');
    });

    test('updateSourceNote returns the kind the cap refused', () async {
      final ten = [for (var i = 0; i < 10; i++) 'tag$i'];
      await notifier().setCollectionTags(TagKind.topic, ten);
      final refused = await notifier().updateSourceNote('p1', topic: ['extra']);
      expect(refused, {TagKind.topic});
      expect(shown().sources.single.topicTags, ['extra'],
          reason: 'the source keeps it');
      expect(shown().topicTags, ten);
      expect(await notifier().updateSourceNote('nope', topic: ['x']), isEmpty);
    });
  });

  group('leaving', () {
    setUp(() => open(withWords: false));
    tearDown(close);

    test('a collection with only a description is kept', () async {
      // A fresh empty one with no source.
      final bare = await store.create(folderId: null, keep: false);
      await store.setCurrentCollectionId(bare.collectionId);
      container.invalidate(wordsProvider);
      await container.read(wordsProvider.future);
      expect(await notifier().saveDetails(description: 'Notes only'), isTrue);
      await notifier().newCollection(null);
      expect(await store.byId(bare.collectionId), isNotNull);
    });
  });

  group('the main screen tag line', () {
    testWidgets('shows the collection tags, growing the bar over 200 ms',
        (tester) async {
      await tester.runAsync(open);
      // The screen's store streams keep close() waiting; the dir is removed.
      addTearDown(() {
        container.dispose();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'), (_) async => null);
      SharedPreferences.setMockInitialValues({'word_detail_mode': 'both'});
      await tester.runAsync(() async {
        container.read(wordDetailModeProvider);
        await container.read(wordDetailModeProvider.notifier).loaded;
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WordsScreen()),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(CollectionTagLine), findsOneWidget);
      expect(tester.getSize(find.byType(CollectionTagLine)).height, 0);
      final bare = tester.getSize(find.byType(AppBar)).height;

      await tester.runAsync(
          () => notifier().saveDetails(origin: ['Quizlet'], topic: ['travel']));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getSize(find.byType(AppBar)).height;
      expect(mid, greaterThan(bare));
      expect(mid, lessThan(bare + CollectionTagLine.lineHeight));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Quizlet'), findsOneWidget);
      expect(find.text('travel'), findsOneWidget);
      expect(tester.getSize(find.byType(AppBar)).height,
          bare + CollectionTagLine.lineHeight);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
