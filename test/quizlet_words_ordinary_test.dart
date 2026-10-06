// import-from-quizlet T15: words kept from a Quizlet set behave like typed
// words in the input rows, the words table, History and the AnkiDroid export
// (spec AC-17, US-06, docs/lightning_icon_rules.md).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/core/services/source_photo_store.dart';
import 'package:flutter_vocabulary_app/features/history/history_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/quizlet_read_controller.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';
import 'package:flutter_vocabulary_app/features/words_table/anki_export.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

class FakePageDriver implements QuizletPageDriver {
  FakePageDriver(this.reply);
  final String reply;

  @override
  void open(
    Uri url, {
    required void Function() onPageFinished,
    required void Function(String reason) onLoadError,
  }) {
    scheduleMicrotask(onPageFinished);
  }

  @override
  Future<Object?> runReader() async => reply;

  @override
  Widget buildView() => const ColoredBox(color: Colors.grey);

  @override
  void stop() {}
}

/// The import machine-translates nothing: any call is counted.
class FakeTranslate extends GoogleTranslateService {
  int calls = 0;

  @override
  Future<WordTranslation> translateWord(String word,
      {required String to, String from = 'en'}) async {
    calls++;
    return WordTranslation(
        result: TranslationResult(text: 'т-$word'), best: 'т-$word');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late SessionStore store;

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('quizlet_words_ordinary_test');
    store = await SessionStore.open(directory: dir.path);
    final session = Session.create();
    await store.put(session);
    await store.setCurrentSessionId(session.sessionId);
  });

  // The store is not closed: a debounced save started inside the widget
  // test's fake async never finishes, and close() would wait for it.
  tearDownAll(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets(
      'set words: no lightning where the card gave the text, a definition '
      'lightning where it had no back; table, History and export list them',
      (tester) async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'both'});
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (_) async => null);
    final translate = FakeTranslate();
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      googleTranslateServiceProvider.overrideWithValue(translate),
    ]);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
    });
    final reply = jsonEncode({
      'setId': '123456',
      'name': 'Animals',
      'heading': 'Terms in this set (2)',
      'embedded': null,
      'visible': [
        ['cat', 'a small animal'],
        ['dog', 'пес'],
      ],
      'robot': '',
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: WordInputScreen(
            quizletDriverFactory: (_) => FakePageDriver(reply)),
      ),
    ));
    await tester.pump();

    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await tester.tap(find.byIcon(Icons.add));
    await settle();
    await tester.tap(find.text('Import from Quizlet'));
    await settle();
    await tester.enterText(find.byKey(const Key('quizlet-link')),
        'https://quizlet.com/123456/animals/');
    await tester.tap(find.text('Start'));
    // The cards' skeleton second and two-second scroll.
    for (var i = 0; i < 3; i++) {
      await settle();
    }
    await tester.tap(find.text('Done'));
    await settle();

    Session session() => container.read(wordInputNotifierProvider).value!;
    // Blank rows may sit between batches, as after a photo import; they are
    // not words.
    final rows = session().words.where((p) => !p.isEmpty).toList();
    final cat = rows[0];
    final dog = rows[1];
    expect(rows.length, 2);
    expect([cat.word, dog.word], ['cat', 'dog']);
    expect(cat.sourceId, 'quizlet-123456');

    // Input rows: the lightnings follow the typed-word rules.
    Finder field(String label, int row) => find
        .byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == label)
        .at(row);
    // The input rows, blank ones included: the row a word sits on.
    int rowOf(String word) => tester
        .widgetList<TextField>(find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Word'))
        .toList()
        .indexWhere((f) => f.controller?.text == word);
    final definitionBolt = find.byTooltip('Look up definition');
    final translationBolt = find.byTooltip('AI Translate');

    expect(translate.calls, 0, reason: 'nothing is machine-translated');

    // An English back is the definition: no definition lightning; the
    // translation is empty, so its lightning shows -- as for a typed word.
    expect(cat.definition, 'a small animal');
    expect(cat.translation, '');
    await tester.showKeyboard(field('Definition', rowOf('cat')));
    await tester.pump();
    expect(definitionBolt, findsNothing);
    await tester.showKeyboard(field('Translation', rowOf('cat')));
    await tester.pump();
    expect(translationBolt, findsOneWidget);

    // A Ukrainian back is the translation: no translation lightning; the
    // definition is empty, so only the definition lightning shows.
    expect(dog.definition, '');
    expect(dog.translation, 'пес');
    await tester.showKeyboard(field('Definition', rowOf('dog')));
    await tester.pump();
    expect(definitionBolt, findsOneWidget);
    expect(translationBolt, findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    final kept = Session.create()
      ..words = [
        for (final p in rows)
          WordPair(
              word: p.word,
              translation: p.translation,
              definition: p.definition,
              sourceId: p.sourceId)
      ];
    container.dispose();

    // Words table, opened on a stored session as History does.
    final photoDir = Directory.systemTemp.createTempSync('ordinary_photos');
    addTearDown(() => photoDir.deleteSync(recursive: true));
    final tableContainer = ProviderContainer(overrides: [
      sessionByIdProvider(kept.sessionId).overrideWith((ref) async => kept),
      nonEmptySessionsProvider.overrideWith((ref) => Stream.value([kept])),
      sourcePhotoStoreProvider
          .overrideWithValue(SourcePhotoStore(directory: photoDir.path)),
    ]);
    addTearDown(tableContainer.dispose);
    await tester.runAsync(() async {
      tableContainer.read(wordDetailModeProvider);
      await tableContainer.read(wordDetailModeProvider.notifier).loaded;
      await tableContainer.read(sessionByIdProvider(kept.sessionId).future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: tableContainer,
      child: MaterialApp(home: WordsTableScreen(sessionId: kept.sessionId)),
    ));
    await tester.pump();
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('a small animal'), findsOneWidget);
    expect(find.text('dog'), findsOneWidget);
    expect(find.text('пес'), findsOneWidget);

    // History lists the session with its set words counted.
    await tester.pumpWidget(UncontrolledProviderScope(
      container: tableContainer,
      child: const MaterialApp(home: HistoryScreen()),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('2 words'), findsOneWidget);

    // AnkiDroid export: set words are ordinary records.
    expect(
      generateAnkiFile(kept.words, detail: WordDetailMode.both),
      '#separator:tab\n#html:true\n#tags column:4\n'
      'cat\t\ta small animal\t\n'
      'dog\tпес\t\t\n',
    );
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 60)));
}
