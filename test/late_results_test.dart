import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// collections-screen T13 (ADR-0006, AC-11, AC-27): a translation lookup, a
/// photo reading, a Quizlet import and a subtitle import started in A that
/// finish after B was opened are written into A through the store's atomic
/// update, also when A is in the bin, never into B; for an erased A nothing is
/// written.
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
  late WordInputNotifier notifier;
  late String a;
  late String b;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('late_results_test');
    store = await CollectionStore.open(directory: dir.path);
    container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
    final first = await container.read(wordInputNotifierProvider.future);
    notifier = container.read(wordInputNotifierProvider.notifier);
    a = first.collectionId;
    notifier.setPairs([WordPair(word: 'tide', rowId: 'row-1'), WordPair()]);
    await notifier.flush();
    final second = await store.create(keep: true);
    b = second.collectionId;
    // The learner opens B while the work for A is still out.
    expect(await notifier.switchTo(b), isTrue);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<List<WordPair>> wordsOf(String id) async =>
      (await store.byId(id))!.words.where((w) => !w.isEmpty).toList();

  Future<void> binA() async {
    await store.bin(a);
    expect((await store.byId(a))!.binnedAt, isNotNull);
  }

  group('translation lookup', () {
    test('lands on its row in A, not in B', () async {
      final ok = await notifier.updateRowIn(a, 'row-1', (row) {
        row.translation = 'приплив';
        row.translationMarkedFilled = true;
        row.translationOptions = const TranslationResult(text: 'приплив');
        row.hasTranslationOptions = true;
      });
      expect(ok, isTrue);
      final words = await wordsOf(a);
      expect(words.single.word, 'tide');
      expect(words.single.translation, 'приплив');
      expect(words.single.translationOptions, isNotNull);
      expect(await wordsOf(b), isEmpty);
    });

    test('lands in A while A is in the bin', () async {
      await binA();
      expect(
          await notifier.updateRowIn(a, 'row-1', (r) => r.translation = 'x'),
          isTrue);
      expect((await wordsOf(a)).single.translation, 'x');
    });

    test('a row without an id is found by the texts it had at Start', () async {
      expect(
          await notifier.updateRowIn(a, '', (r) => r.translation = 'приплив',
              word: 'tide'),
          isTrue);
      expect((await wordsOf(a)).single.translation, 'приплив');
    });

    test('a row the learner removed is skipped', () async {
      expect(
          await notifier.updateRowIn(a, 'gone', (r) => r.translation = 'x'),
          isTrue);
      expect((await wordsOf(a)).single.translation, '');
    });

    test('erased A: dropped', () async {
      await binA();
      await store.erase(a);
      expect(
          await notifier.updateRowIn(a, 'row-1', (r) => r.translation = 'x'),
          isFalse);
      expect(await store.byId(a), isNull);
      expect(await wordsOf(b), isEmpty);
    });
  });

  group('photo reading', () {
    final photo = SessionSource()
      ..id = 'photo-1'
      ..takenAt = DateTime(2026, 10, 16)
      ..kind = SourceKind.photo;

    test('rows and the photo source land in A, rows pointing at it', () async {
      final ok = await notifier.addWordsTo(a,
          [WordPair(word: 'gull'), WordPair(word: 'wave')],
          photo: photo);
      expect(ok, isTrue);
      final stored = (await store.byId(a))!;
      expect(stored.sources.map((s) => s.id), ['photo-1']);
      final words = await wordsOf(a);
      expect(words.map((w) => w.word), ['tide', 'gull', 'wave']);
      expect(words.skip(1).map((w) => w.sourceId), ['photo-1', 'photo-1']);
      expect(words.every((w) => w.rowId.isNotEmpty), isTrue);
      expect(await wordsOf(b), isEmpty);
      expect((await store.byId(b))!.sources, isEmpty);
    });

    test('lands in A while A is in the bin', () async {
      await binA();
      expect(await notifier.addWordsTo(a, [WordPair(word: 'gull')], photo: photo),
          isTrue);
      expect((await wordsOf(a)).map((w) => w.word), ['tide', 'gull']);
    });

    test('erased A: nothing written, B untouched', () async {
      await binA();
      await store.erase(a);
      expect(await notifier.addWordsTo(a, [WordPair(word: 'gull')], photo: photo),
          isFalse);
      expect(await wordsOf(b), isEmpty);
    });
  });

  group('Quizlet import', () {
    test('words land in A under the set source; a repeat reuses the source',
        () async {
      const set = (id: '123', name: 'Animals', url: 'https://quizlet.com/123');
      expect(await notifier.addWordsTo(a, [WordPair(word: 'cat')], set: set),
          isTrue);
      expect(
          await notifier.addWordsTo(a, [WordPair(word: 'dog')],
              set: (id: '123', name: 'Animals 2', url: set.url)),
          isTrue);
      final stored = (await store.byId(a))!;
      expect(stored.sources.single.id, 'quizlet-123');
      expect(stored.sources.single.name, 'Animals 2');
      expect((await wordsOf(a)).skip(1).map((w) => w.sourceId),
          ['quizlet-123', 'quizlet-123']);
      expect(await wordsOf(b), isEmpty);
    });

    test('erased A: dropped', () async {
      await binA();
      await store.erase(a);
      expect(
          await notifier.addWordsTo(a, [WordPair(word: 'cat')],
              set: (id: '1', name: 'n', url: 'u')),
          isFalse);
    });
  });

  group('subtitle import', () {
    test('words, film source and dialogues land in A', () async {
      final ok = await notifier.addWordsTo(
        a,
        [WordPair(word: 'reluctant'), WordPair(word: 'grumble')],
        film: 'The Office',
        poster: 'https://img/p.jpg',
        dialogues: [
          (lines: ['He was reluctant.', 'Do not grumble.'], words: ['reluctant', 'grumble']),
        ],
      );
      expect(ok, isTrue);
      final stored = (await store.byId(a))!;
      expect(stored.sources.single.kind, SourceKind.subtitles);
      expect(stored.sources.single.name, 'The Office');
      expect(stored.sources.single.url, 'https://img/p.jpg');
      final words = await wordsOf(a);
      expect(words.map((w) => w.word), ['tide', 'reluctant', 'grumble']);
      expect(words.skip(1).every((w) => w.sourceId == stored.sources.single.id),
          isTrue);
      expect(stored.dialogues, hasLength(1));
      expect(stored.dialogues.single.wordRowIds, [words[1].rowId, words[2].rowId]);
      final inB = (await store.byId(b))!;
      expect(inB.dialogues, isEmpty);
      expect(inB.sources, isEmpty);
    });

    test('erased A: dropped', () async {
      await binA();
      await store.erase(a);
      expect(await notifier.addWordsTo(a, [WordPair(word: 'x')], film: 'F'),
          isFalse);
    });
  });
}
