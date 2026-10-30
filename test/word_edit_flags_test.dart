import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/definition_result.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/dictionary_service.dart';
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/definition_dots_button.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/translation_dots_button.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words/words_screen.dart';

import 'seed_collections.dart';

/// word-context T5 (AC-04, AC-05): a learner's change of the translation or
/// the definition sets its edit flag, an app fill does not, and a changed
/// English word clears the context, its kind, both flags and `contextTried`.
class FakeTranslate extends GoogleTranslateService {
  @override
  Future<WordTranslation> translateWord(String word,
      {required String to, String from = 'en'}) async {
    return WordTranslation(
        result: TranslationResult(text: 'т-$word'), best: 'т-$word');
  }
}

class FakeDictionary extends DictionaryService {
  @override
  Future<DefinitionResult> define(String word) async =>
      DefinitionResult.found(['sense of $word', 'other sense of $word']);
}

WordOrigin filmOrigin({bool edited = false}) => WordOrigin()
  ..typeOfSource = SourceType.movie
  ..movieName = 'Friends'
  ..season = 2
  ..episode = 5
  ..time = '00:01:02'
  ..wasTranslationEditByUser = edited
  ..wasDescriptionEditByUser = edited;

WordPair withContext(WordPair row) => row
  ..context = 'A cat sat on the mat.'
  ..contextKind = ContextKind.source
  ..contextTried = true;

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

  group('WordsNotifier.updateAt', () {
    late Directory dir;
    late CollectionStore store;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('word_edit_flags_test');
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

    Future<WordsNotifier> seeded(List<WordPair> pairs) async {
      await container.read(wordsProvider.future);
      final notifier = container.read(wordsProvider.notifier);
      notifier.setPairs(pairs);
      return notifier;
    }

    List<WordPair> words() => container.read(wordsProvider).value!.words;

    test('a learner edit sets its flag; an app fill sets none', () async {
      final notifier = await seeded([
        WordPair(word: 'cat', translation: 'кіт', definition: 'a pet')
          ..origin = filmOrigin(),
      ]);

      notifier.updateAt(0, translation: 'кішка', definition: 'an animal');
      expect(words()[0].origin.wasTranslationEditByUser, isFalse);
      expect(words()[0].origin.wasDescriptionEditByUser, isFalse);

      notifier.updateAt(0,
          translation: 'котик', translationEditedByLearner: true);
      expect(words()[0].translation, 'котик');
      expect(words()[0].origin.wasTranslationEditByUser, isTrue);
      expect(words()[0].origin.wasDescriptionEditByUser, isFalse);

      notifier.updateAt(0,
          definition: 'a small pet', definitionEditedByLearner: true);
      expect(words()[0].origin.wasTranslationEditByUser, isTrue);
      expect(words()[0].origin.wasDescriptionEditByUser, isTrue);

      // A later app fill keeps the flags.
      notifier.updateAt(0, translation: 'кіт');
      expect(words()[0].origin.wasTranslationEditByUser, isTrue);
      expect(words()[0].origin.movieName, 'Friends');
    });

    test('a changed word clears context, its kind, flags and contextTried',
        () async {
      final notifier = await seeded([
        withContext(WordPair(word: 'cat', translation: 'кіт')
          ..origin = filmOrigin(edited: true)),
      ]);

      notifier.updateAt(0, word: 'cats', wordChanged: true);

      final row = words()[0];
      expect(row.word, 'cats');
      expect(row.translation, 'кіт');
      expect(row.context, '');
      expect(row.contextKind, ContextKind.none);
      expect(row.contextTried, isFalse);
      expect(row.origin.wasTranslationEditByUser, isFalse);
      expect(row.origin.wasDescriptionEditByUser, isFalse);
      expect(row.origin.typeOfSource, SourceType.movie);
      expect(row.origin.movieName, 'Friends');
      expect(row.origin.season, 2);
      expect(row.origin.episode, 5);
      expect(row.origin.time, '00:01:02');
    });

    test('a changed definition clears contextTried; the same one keeps it',
        () async {
      final notifier = await seeded([
        withContext(
            WordPair(word: 'cat', translation: 'кіт', definition: 'a pet')),
      ]);

      notifier.updateAt(0, definition: 'a pet');
      expect(words()[0].contextTried, isTrue);

      notifier.updateAt(0, definition: 'a small animal');
      expect(words()[0].contextTried, isFalse);
      expect(words()[0].context, 'A cat sat on the mat.');
    });
  });

  testWidgets(
      'typing and ⋯ picks set the flags, lightning does not, a new '
      'word clears the context', (tester) async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'both'});
    // Tall enough for every row to be built.
    tester.view.physicalSize = const Size(1179, 8000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory dir;
    late CollectionStore store;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('word_edit_flags_widget');
      store = await CollectionStore.open(directory: dir.path);
      final collection = WordCollection.create()
        ..words = [
          WordPair(word: 'tenacious'),
          WordPair(word: 'claim', translation: 'заява', definition: 'to ask'),
          WordPair(word: 'run', translation: 'бігти', definition: 'go'),
          withContext(WordPair(word: 'cat', translation: 'кіт')
            ..origin = filmOrigin(edited: true)),
        ];
      await seedCollection(store, collection);
      await store.setCurrentCollectionId(collection.collectionId);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      googleTranslateServiceProvider.overrideWithValue(FakeTranslate()),
      dictionaryServiceProvider.overrideWithValue(FakeDictionary()),
    ]);
    await tester.runAsync(() async {
      await container.read(wordsProvider.future);
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordsScreen()),
    ));
    await tester.pump();
    await tester.pump();

    List<WordPair> words() => container.read(wordsProvider).value!.words;
    Finder field(String text) => find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == text);
    void press(String tooltip) => tester
        .widget<IconButton>(find
            .byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip))
        .onPressed!();

    // Lightning: both fields filled by the app, no flag.
    await tester.showKeyboard(field('tenacious'));
    await tester.pump();
    press('AI Translate');
    await tester.pump();
    await tester.pump();
    press('Look up definition');
    await tester.pump();
    await tester.pump();
    expect(words()[0].translation, 'т-tenacious');
    expect(words()[0].definition, 'sense of tenacious');
    expect(words()[0].origin.wasTranslationEditByUser, isFalse);
    expect(words()[0].origin.wasDescriptionEditByUser, isFalse);

    // Typing: each field sets its own flag.
    await tester.enterText(field('заява'), 'вимога');
    await tester.pump();
    expect(words()[1].origin.wasTranslationEditByUser, isTrue);
    expect(words()[1].origin.wasDescriptionEditByUser, isFalse);
    await tester.enterText(field('to ask'), 'to demand');
    await tester.pump();
    expect(words()[1].origin.wasDescriptionEditByUser, isTrue);

    // A pick from the ⋯ list: the same value changes nothing, another sets
    // the flag.
    final translationDots = tester
        .widgetList<TranslationDotsButton>(find.byType(TranslationDotsButton))
        .toList();
    final definitionDots = tester
        .widgetList<DefinitionDotsButton>(find.byType(DefinitionDotsButton))
        .toList();
    translationDots[2].onSelectTranslation('бігти');
    definitionDots[2].onSelectSense('go');
    await tester.pump();
    expect(words()[2].origin.wasTranslationEditByUser, isFalse);
    expect(words()[2].origin.wasDescriptionEditByUser, isFalse);
    translationDots[2].onSelectTranslation('бігати');
    await tester.pump();
    expect(words()[2].translation, 'бігати');
    expect(words()[2].origin.wasTranslationEditByUser, isTrue);
    expect(words()[2].origin.wasDescriptionEditByUser, isFalse);
    definitionDots[2].onSelectSense('move fast');
    await tester.pump();
    expect(words()[2].definition, 'move fast');
    expect(words()[2].origin.wasDescriptionEditByUser, isTrue);

    // A new English word: context and flags go, the source type stays.
    await tester.enterText(field('cat'), 'cats');
    await tester.pump();
    final row = words()[3];
    expect(row.word, 'cats');
    expect(row.context, '');
    expect(row.contextKind, ContextKind.none);
    expect(row.contextTried, isFalse);
    expect(row.origin.wasTranslationEditByUser, isFalse);
    expect(row.origin.wasDescriptionEditByUser, isFalse);
    expect(row.origin.typeOfSource, SourceType.movie);
    expect(row.origin.movieName, 'Friends');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
