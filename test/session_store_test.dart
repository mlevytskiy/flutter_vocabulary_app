import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';

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
  late SessionStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('session_store_test');
    store = await SessionStore.open(directory: dir.path);
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
      final session = Session.create()
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

      await store.put(session);
      final back = await store.byId(session.sessionId);

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
      final session = Session.create()
        ..words = [
          WordPair(word: 'a', translation: 'а'),
          WordPair(word: 'b', translation: 'б'),
          WordPair(),
        ];

      await store.put(session);

      expect((await store.byId(session.sessionId))!.words.length, 2);
      // ...and the caller's own list is left alone.
      expect(session.words.length, 3);
    });

    // AC-4
    test('an empty store answers with null / [] and never throws', () async {
      expect(await store.newest(), isNull);
      expect(await store.nonEmpty(), isEmpty);
      expect(await store.byId('nope'), isNull);
      expect(await store.currentSessionId(), isNull);
    });

    // AC-5
    test('nonEmpty() skips all-blank sessions; watchNonEmpty() emits on write',
        () async {
      final blank = Session.create()..words = [WordPair()];
      await store.put(blank);
      expect(await store.nonEmpty(), isEmpty);

      final emissions = <List<Session>>[];
      final sub = store.watchNonEmpty().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.length, 1, reason: 'fireImmediately');
      expect(emissions.first, isEmpty);

      final filled = Session.create()
        ..words = [WordPair(word: 'a', translation: 'а')];
      await store.put(filled);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions.length, greaterThan(1));
      expect(emissions.last.map((s) => s.sessionId), [filled.sessionId]);
      await sub.cancel();
    });

    test('newest() is the session this device touched last', () async {
      final older = Session.create()
        ..words = [WordPair(word: 'old', translation: 'старе')]
        ..lastLocalModifiedAt =
            DateTime.now().subtract(const Duration(hours: 2));
      final newer = Session.create()
        ..words = [WordPair(word: 'new', translation: 'нове')];
      await store.put(older);
      await store.put(newer);

      expect((await store.newest())!.sessionId, newer.sessionId);
      expect((await store.nonEmpty()).map((s) => s.sessionId).toList(),
          [newer.sessionId, older.sessionId]);
    });

    test('put upserts on sessionId instead of piling up rows', () async {
      final session = Session.create()
        ..words = [WordPair(word: 'a', translation: 'а')];
      await store.put(session);
      session.words.add(WordPair(word: 'b', translation: 'б'));
      await store.put(session);

      expect((await store.nonEmpty()).length, 1);
      expect((await store.byId(session.sessionId))!.words.length, 2);
    });

    test('delete removes the session; the pointer round-trips', () async {
      final session = Session.create()
        ..words = [WordPair(word: 'a', translation: 'а')];
      await store.put(session);
      await store.setCurrentSessionId(session.sessionId);
      expect(await store.currentSessionId(), session.sessionId);

      await store.delete(session.sessionId);
      expect(await store.byId(session.sessionId), isNull);
      expect(await store.nonEmpty(), isEmpty);
    });
  });
}
