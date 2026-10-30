import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/definition_result.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/definition_dots_button.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/dictionary_service.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words/words_screen.dart';

import 'seed_collections.dart';

/// word-context T9: a filled or picked dictionary sense gives the row its
/// example as context (AC-02, AC-11).
const _cupel = 'definition: persistent\nexample: a tenacious fighter';
const _other = 'definition: retentive\nexample: a tenacious memory';

class _Dictionary extends DictionaryService {
  @override
  Future<DefinitionResult> define(String word) async {
    switch (word) {
      case 'tenacious':
      case 'film':
        return const DefinitionResult.found([_cupel, _other]);
      case 'plain':
        return const DefinitionResult.found(['definition: simple']);
      default:
        return const DefinitionResult.unavailable();
    }
  }
}

void main() {
  test('DefinitionResult exposes each sense example', () {
    const r =
        DefinitionResult.found([_cupel, 'definition: simple', 'x\nexample:  ']);
    expect(r.examples, ['a tenacious fighter', null, null]);
    expect(r.exampleAt(0), 'a tenacious fighter');
    expect(r.exampleAt(5), isNull);
  });

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

  testWidgets('lightning and pick set the example as context', (tester) async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'definition'});
    late Directory dir;
    late CollectionStore store;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('definition_context_test');
      store = await CollectionStore.open(directory: dir.path);
      final collection = WordCollection.create()
        ..words = [
          WordPair(word: 'tenacious'),
          WordPair(
              word: 'plain',
              context: 'kept line',
              contextKind: ContextKind.source),
          WordPair(
              word: 'film',
              context: 'film line',
              contextKind: ContextKind.source)
            ..origin.typeOfSource = SourceType.movie,
          WordPair(word: 'cat', translation: 'кіт'),
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
      dictionaryServiceProvider.overrideWithValue(_Dictionary()),
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
    container
        .read(wordsProvider.notifier)
        .setPairs(List.of(container.read(wordsProvider).value!.words));
    await tester.pump();
    await tester.pump();

    List<WordPair> words() => container.read(wordsProvider).value!.words;
    Finder definitionField(int row) => find
        .byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Definition')
        .at(row);
    void pressBolt() => tester
        .widget<IconButton>(find.ancestor(
            of: find.byIcon(Icons.electric_bolt),
            matching: find.byType(IconButton)))
        .onPressed!();
    Future<void> lightning(int row) async {
      await tester.showKeyboard(definitionField(row));
      await tester.pump();
      pressBolt();
      await tester.pump();
      await tester.pump();
    }

    // Typed row: the first sense's example becomes the context, kind source.
    await lightning(0);
    expect(words()[0].definition, _cupel);
    expect(words()[0].context, 'a tenacious fighter');
    expect(words()[0].contextKind, ContextKind.source);

    // A sense without an example leaves the context as it was.
    await lightning(1);
    expect(words()[1].definition, 'definition: simple');
    expect(words()[1].context, 'kept line');

    // A film row keeps its own line.
    await lightning(2);
    expect(words()[2].definition, _cupel);
    expect(words()[2].context, 'film line');

    // A translation-only row stays empty.
    expect(words()[3].context, '');
    expect(words()[3].contextKind, ContextKind.none);

    // Picking another sense on the typed row replaces the context.
    // (called directly: the harness's hit test misses the popup, see
    // definition_lightning_test.dart)
    tester
        .widget<DefinitionDotsButton>(find.byType(DefinitionDotsButton).first)
        .onSelectSense(_other);
    await tester.pump();
    expect(words()[0].definition, _other);
    expect(words()[0].context, 'a tenacious memory');
    expect(words()[0].contextKind, ContextKind.source);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
