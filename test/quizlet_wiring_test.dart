// import-from-quizlet T13: "Import from Quizlet" in the red + menu, and the
// set kept as the words' source (sad §6 F3 Done branch, ADR-0005); AC-01,
// AC-03, AC-13b, AC-17.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/quizlet_read_controller.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_input_speed_dial.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// Stands in for the web view: loads at once and returns [reply].
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

/// Translates every term to "т-<term>" at once.
class FakeTranslate extends GoogleTranslateService {
  @override
  Future<WordTranslation> translateWord(String word,
          {required String to, String from = 'en'}) async =>
      WordTranslation(
          result: TranslationResult(text: 'т-$word'), best: 'т-$word');
}

String page(String name, List<List<String>> cards) => jsonEncode({
      'setId': '123456',
      'name': name,
      'heading': 'Terms in this set (${cards.length})',
      'embedded': null,
      'visible': cards,
      'robot': '',
    });

SessionSource photo(String id) => SessionSource()
  ..id = id
  ..fileName = '$id.jpg'
  ..takenAt = DateTime(2026);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speed dial (AC-01)', () {
    Future<void> pumpDial(WidgetTester tester, VoidCallback onQuizlet) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            floatingActionButton: WordInputSpeedDial(
              onTakePhoto: () {},
              onFromSubtitles: () {},
              onImportFromQuizlet: onQuizlet,
            ),
          ),
        ));

    testWidgets('"Import from Quizlet" sits in green where Screenshot was',
        (tester) async {
      await pumpDial(tester, () {});
      await tester.pumpAndSettle();
      final children =
          tester.widget<SpeedDial>(find.byType(SpeedDial)).children;
      expect(children.map((c) => c.label),
          ['Get words from photo', 'From subtitles', 'Import from Quizlet']);
      expect(children.last.backgroundColor, Colors.green);
      expect(children.last.foregroundColor, Colors.white);
    });

    testWidgets('choosing it starts the import', (tester) async {
      var tapped = 0;
      await pumpDial(tester, () => tapped++);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('Screenshot'), findsNothing);
      await tester.tap(find.text('Import from Quizlet'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });
  });

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
    dir = Directory.systemTemp.createTempSync('quizlet_wiring_test');
    store = await SessionStore.open(directory: dir.path);
    final session = Session.create()
      ..words = [WordPair(word: 'harbour', sourceId: 'photo-a')]
      ..sources = [photo('photo-a'), photo('photo-b')];
    await store.put(session);
    await store.setCurrentSessionId(session.sessionId);
  });

  // The store is not closed: a debounced save started inside the widget
  // test's fake async never finishes, and close() would wait for it.
  tearDownAll(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('notifier upsertSetSource (AC-13b)', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer(overrides: [
          sessionStoreProvider.overrideWith((ref) async => store),
        ]));
    tearDown(() => container.dispose());

    test('adds the set after the existing sources, then renames it in place',
        () async {
      await container.read(wordInputNotifierProvider.future);
      final notifier = container.read(wordInputNotifierProvider.notifier);

      final id = notifier.upsertSetSource(
          '123456', 'Animals', 'https://quizlet.com/123456/animals/');
      expect(id, 'quizlet-123456');
      notifier.addSource(photo('photo-c'));
      final again = notifier.upsertSetSource(
          '123456', 'Wild animals', 'https://quizlet.com/123456/wild/');
      expect(again, 'quizlet-123456');

      final sources = container.read(wordInputNotifierProvider).value!.sources;
      expect(sources.map((s) => s.id),
          ['photo-a', 'photo-b', 'quizlet-123456', 'photo-c']);
      final set = sources[2];
      expect(set.kind, SourceKind.set);
      expect(set.name, 'Wild animals');
      expect(set.url, 'https://quizlet.com/123456/wild/');
      expect(set.fileName, '');
    });
  });

  group('main screen (AC-03, AC-13b, AC-17)', () {
    late ProviderContainer container;
    var reply = '';

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> importFrom(WidgetTester tester, String pasted) async {
      await tester.tap(find.byIcon(Icons.add));
      await settle(tester);
      await tester.tap(find.text('Import from Quizlet'));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('quizlet-link')), pasted);
      await tester.tap(find.text('Start'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);
    }

    testWidgets(
        'Done appends the kept words in set order with the set id; a '
        're-import from another link shape keeps one renamed set source',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'), (_) async => null);
      container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((ref) async => store),
        googleTranslateServiceProvider.overrideWithValue(FakeTranslate()),
      ]);
      await tester
          .runAsync(() => container.read(wordInputNotifierProvider.future));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: WordInputScreen(
              quizletDriverFactory: (_) => FakePageDriver(reply)),
        ),
      ));
      await tester.pump();

      reply = page('Animals', [
        ['cat', 'a small animal'],
        ['dog', ''],
      ]);
      await importFrom(tester,
          'Check out this set: https://quizlet.com/ua/123456/animals/?x=1');

      Session session() => container.read(wordInputNotifierProvider).value!;
      List<WordPair> rows() =>
          session().words.where((p) => !p.isEmpty).toList();

      expect(rows().map((p) => p.word), ['harbour', 'cat', 'dog']);
      expect(rows().map((p) => p.sourceId),
          ['photo-a', 'quizlet-123456', 'quizlet-123456']);
      expect(rows()[1].translation, 'т-cat');
      expect(rows()[1].translationMarkedFilled, isTrue);
      expect(rows()[1].definition, 'a small animal');
      expect(rows()[1].definitionMarkedFilled, isTrue);
      expect(rows()[2].definition, '');
      expect(rows()[2].definitionMarkedFilled, isFalse);
      expect(session().sources.map((s) => s.id),
          ['photo-a', 'photo-b', 'quizlet-123456']);
      expect(session().sources.last.name, 'Animals');
      expect(session().sources.last.kind, SourceKind.set);

      reply = page('Wild animals', [
        ['cat', 'a small animal'],
        ['fox', 'a red animal'],
      ]);
      await importFrom(tester, 'quizlet.com/123456/wild-animals/flashcards');

      expect(rows().map((p) => p.word), ['harbour', 'cat', 'dog', 'fox']);
      expect(rows().last.sourceId, 'quizlet-123456');
      expect(
          session().sources.where((s) => s.kind == SourceKind.set).length, 1);
      expect(session().sources.map((s) => s.id),
          ['photo-a', 'photo-b', 'quizlet-123456']);
      expect(session().sources.last.name, 'Wild animals');
      expect(session().sources.last.url,
          'https://quizlet.com/123456/wild-animals/');

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });
}
