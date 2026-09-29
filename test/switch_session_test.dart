import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/definition_result.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/dictionary_service.dart';
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// edit-session-from-history T5 (ADR-0003, AC-07b, AC-09): a lookup that comes
/// back after a switch never lands in the picked session, and a RESTORE offer
/// from the last launch goes away with the switch.
///
/// The photo path is not covered here: it runs through `PhotoScaler.instance`
/// and the image_picker / flutter_image_compress platform channels, which this
/// harness cannot fake without new packages. It is checked on the device (T6).
class _SlowTranslate extends GoogleTranslateService {
  final gate = Completer<void>();
  final calls = <String>[];

  @override
  Future<WordTranslation> translateWord(String word,
      {required String to, String from = 'en'}) async {
    calls.add(word);
    await gate.future;
    const result = TranslationResult(
        text: 'яблуко',
        alternatives: ['яблуко'],
        detectedSourceLanguage: 'en',
        dictionary: []);
    return const WordTranslation(result: result, best: 'яблуко');
  }
}

class _SlowDictionary extends DictionaryService {
  final gate = Completer<void>();
  final calls = <String>[];

  @override
  Future<DefinitionResult> define(String word) async {
    calls.add(word);
    await gate.future;
    return const DefinitionResult.found(['a round fruit']);
  }
}

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

  // One store for the whole file, never closed: closing an Isar the screen
  // has watched under the fake clock never returns (definition_lightning_test
  // leaves its store open for the same reason). Each test seeds its own
  // sessions and points the current-session pointer at its own.
  Directory? dir;
  late SessionStore store;
  tearDownAll(() {
    if (dir != null && dir!.existsSync()) dir!.deleteSync(recursive: true);
  });
  late ProviderContainer container;
  late Session left;
  late Session picked;

  /// [left] is current (warm unless [leftAgo] says otherwise), [picked] is a
  /// past session from History.
  Future<void> pumpMain(WidgetTester tester,
      {Duration leftAgo = Duration.zero,
      GoogleTranslateService? translate,
      DictionaryService? dictionary}) async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'both'});
    await tester.runAsync(() async {
      if (dir == null) {
        dir = Directory.systemTemp.createTempSync('switch_session_test');
        store = await SessionStore.open(directory: dir!.path);
      }
      final leftAt = DateTime.now().subtract(leftAgo);
      left = Session.create()
        ..updatedAt = leftAt
        ..lastLocalModifiedAt = leftAt
        ..words = [WordPair(word: 'apple')];
      final pastAt = DateTime(2026, 9, 1, 12);
      picked = Session.create()
        ..updatedAt = pastAt
        ..lastLocalModifiedAt = pastAt
        ..words = [
          WordPair(word: 'tea', translation: 'чай'),
          WordPair(word: 'milk', translation: 'молоко'),
        ];
      await store.put(left);
      await store.put(picked);
      await store.setCurrentSessionId(left.sessionId);
    });
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      if (translate != null)
        googleTranslateServiceProvider.overrideWithValue(translate),
      if (dictionary != null)
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
    // The session resolved before the screen mounted, so nudge the notifier
    // once for the screen's listener to fill the rows. A blank row is not a
    // content change: it keeps the RESTORE offer and stamps nothing.
    container.read(wordInputNotifierProvider.notifier).addAll([WordPair()]);
    await tester.pump();
    await tester.pump();
  }

  Future<void> tearDownMain(WidgetTester tester) async {
    // Lets flutter_speed_dial's zero-length initState timer fire.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  Future<void> switchToPicked(WidgetTester tester) async {
    await tester.runAsync(() => container
        .read(wordInputNotifierProvider.notifier)
        .switchTo(picked.sessionId));
    await tester.pump();
    await tester.pump();
  }

  List<WordPair> words() =>
      container.read(wordInputNotifierProvider).value!.words;

  Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label);

  Future<void> expectPickedUntouched(WidgetTester tester) async {
    expect(container.read(wordInputNotifierProvider).value!.sessionId,
        picked.sessionId);
    expect(words().where((w) => !w.isEmpty).map((w) => w.word),
        ['tea', 'milk']);
    expect(words().first.translation, 'чай');
    expect(words().first.definition, '');
    expect(find.text('яблуко'), findsNothing);
    expect(find.text('a round fruit'), findsNothing);
    // Whatever is waiting to be saved goes to the store now (in the real
    // zone: a debounced Isar write started under the fake clock never ends).
    await tester.runAsync(
        () => container.read(wordInputNotifierProvider.notifier).flush());
    await tester.runAsync(() async {
      final stored = await store.byId(picked.sessionId);
      expect(stored!.lastLocalModifiedAt, DateTime(2026, 9, 1, 12),
          reason: 'a switch is not an edit (ADR-0002)');
      expect(stored.words.first.translation, 'чай');
      expect(stored.words.first.definition, '');
      final leftStored = await store.byId(left.sessionId);
      expect(leftStored!.words.single.word, 'apple');
      expect(leftStored.words.single.translation, '');
      expect(leftStored.words.single.definition, '');
    });
  }

  testWidgets('a translation that returns after the switch is dropped',
      (tester) async {
    final translate = _SlowTranslate();
    await pumpMain(tester, translate: translate);

    await tester.showKeyboard(field('Word').first);
    await tester.pump();
    _pressIconWithTooltip(tester, 'AI Translate');
    await tester.pump();
    await tester.pump();
    expect(translate.calls, ['apple']);

    await switchToPicked(tester);
    translate.gate.complete();
    await tester.pump();
    await tester.pump();

    await expectPickedUntouched(tester);
    await tearDownMain(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a definition that returns after the switch is dropped',
      (tester) async {
    final dictionary = _SlowDictionary();
    await pumpMain(tester, dictionary: dictionary);

    await tester.showKeyboard(field('Definition').first);
    await tester.pump();
    _pressIconWithTooltip(tester, 'Look up definition');
    await tester.pump();
    expect(dictionary.calls, ['apple']);

    await switchToPicked(tester);
    dictionary.gate.complete();
    await tester.pump();
    await tester.pump();

    await expectPickedUntouched(tester);
    await tearDownMain(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a RESTORE offer on screen goes away with the switch',
      (tester) async {
    await pumpMain(tester, leftAgo: const Duration(days: 7));
    expect(find.text('RESTORE'), findsOneWidget);

    await switchToPicked(tester);
    await tester.pumpAndSettle();

    expect(find.text('RESTORE'), findsNothing);
    expect(words().where((w) => !w.isEmpty).map((w) => w.word),
        ['tea', 'milk']);
    await tearDownMain(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

/// Pressed directly: after showKeyboard scrolls the list, this harness's hit
/// test can miss the row (see definition_lightning_test.dart).
void _pressIconWithTooltip(WidgetTester tester, String tooltip) => tester
    .widget<IconButton>(find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == tooltip))
    .onPressed!();
