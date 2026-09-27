import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/definition_result.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/dictionary_service.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/lightning_rules.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// definition-mode T12: the Definition lightning (spec AC-05..AC-07).
class FakeDictionary extends DictionaryService {
  final lookups = <String>[];

  @override
  Future<DefinitionResult> define(String word) async {
    lookups.add(word);
    switch (word) {
      case 'tenacious':
        return const DefinitionResult.found(['persistent', 'retentive']);
      case 'determinated':
        return const DefinitionResult.notFound(['determinate', 'determined']);
      default:
        return const DefinitionResult.unavailable();
    }
  }
}

void main() {
  group('shouldShowDefinitionIcon', () {
    test('needs focus, a 2+ letter word and an unfilled definition', () {
      expect(
          shouldShowDefinitionIcon(
              rowFocused: true, word: 'claim', definition: '', marked: false),
          isTrue);
      expect(
          shouldShowDefinitionIcon(
              rowFocused: false, word: 'claim', definition: '', marked: false),
          isFalse);
      expect(
          shouldShowDefinitionIcon(
              rowFocused: true, word: 'c', definition: '', marked: false),
          isFalse);
      expect(
          shouldShowDefinitionIcon(
              rowFocused: true,
              word: 'claim',
              definition: 'to ask for',
              marked: false),
          isFalse);
      expect(
          shouldShowDefinitionIcon(
              rowFocused: true, word: 'claim', definition: 'x', marked: true),
          isFalse);
    });
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

  testWidgets('lightning fills the first sense; misses leave the field alone',
      (tester) async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'definition'});
    late Directory dir;
    late SessionStore store;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('definition_lightning_test');
      store = await SessionStore.open(directory: dir.path);
      final session = Session.create()
        ..words = [
          WordPair(word: 'tenacious'),
          WordPair(word: 'determinated'),
          WordPair(word: 'claim', translation: 'заява'),
        ];
      await store.put(session);
      await store.setCurrentSessionId(session.sessionId);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });
    final dictionary = FakeDictionary();
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      dictionaryServiceProvider.overrideWithValue(dictionary),
    ]);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
    ));
    final notifier = container.read(wordInputNotifierProvider.notifier);
    notifier.setPairs(
        List.of(container.read(wordInputNotifierProvider).value!.words));
    await tester.pump();
    await tester.pump();

    List<WordPair> words() =>
        container.read(wordInputNotifierProvider).value!.words;
    Finder definitionField(int row) => find
        .byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Definition')
        .at(row);
    final bolt = find.byTooltip('Look up definition');
    // Pressed directly: after showKeyboard scrolls the list, this harness's
    // hit test misses the row. That the icon is tappable is covered in
    // word_row_layout_test.dart.
    void pressBolt() => tester
        .widget<IconButton>(find.ancestor(
            of: find.byIcon(Icons.electric_bolt),
            matching: find.byType(IconButton)))
        .onPressed!();

    // Found: the first sense fills the field and all senses are stored.
    await tester.showKeyboard(definitionField(0));
    await tester.pump();
    expect(bolt, findsOneWidget);
    pressBolt();
    await tester.pump();
    await tester.pump();
    expect(words()[0].definition, 'persistent');
    expect(DefinitionResult.decodeSenses(words()[0].definitionOptionsJson),
        ['persistent', 'retentive']);
    expect(words()[0].definitionMarkedFilled, isTrue);

    // Not found: the field stays empty and the suggestions are offered.
    await tester.showKeyboard(definitionField(1));
    await tester.pump();
    pressBolt();
    await tester.pump();
    await tester.pump();
    expect(words()[1].definition, '');
    expect(find.textContaining('determined'), findsOneWidget);

    // Unavailable: the field is unchanged and the learner is told.
    await tester.showKeyboard(definitionField(2));
    await tester.pump();
    pressBolt();
    await tester.pump();
    await tester.pump();
    expect(words()[2].definition, '');
    expect(words()[2].translation, 'заява');
    expect(find.textContaining('temporarily unavailable'), findsOneWidget);

    expect(dictionary.lookups, ['tenacious', 'determinated', 'claim']);

    // Lets flutter_speed_dial's zero-length initState timer fire; stays well
    // short of the notifier's 500 ms save debounce (cancelled by dispose).
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
