import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/dialogues/dialogue_rules.dart';
import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_words_service.dart';
import 'package:flutter_vocabulary_app/features/word_input/subtitle_import_flow.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// get-words-from-subtitles-improvment T17: dialogues ride with the subtitle
/// import to Done and are kept with the words in one save (sad §6 flow 1).
class FakeSubtitleWords extends SubtitleWordsService {
  final asked = <bool>[];
  Completer<SubtitleWordsResult>? pending;

  @override
  Future<SubtitleWordsResult> pickWords({
    required List<String> words,
    required Map<String, String> contexts,
    required List<String> lines,
    required int maximum,
    required SubtitleModel model,
    required List<String> sessionWords,
    bool dialogues = false,
  }) {
    asked.add(dialogues);
    pending = Completer();
    return pending!.future;
  }
}

SubtitleWordsResult result(List<String> words, List<ImportedDialogue> dialogues) =>
    SubtitleWordsResult(
      words: [
        for (final w in words)
          VocabWord(word: w, translation: 'т-$w', description: 'd-$w', context: 'c-$w')
      ],
      model: SubtitleModel.sonnet5,
      aiDuration: const Duration(seconds: 3),
      inputTokens: 1,
      outputTokens: 1,
      dialogues: dialogues,
    );

const srtText = '1\n00:00:01,000 --> 00:00:03,000\nI was reluctant to leave.\n';

XFile file() => XFile.fromData(Uint8List.fromList(utf8.encode(srtText)),
    name: 'film.srt', path: 'film.srt');

void main() {
  group('the flow', () {
    late FakeSubtitleWords service;
    late List<VocabWord> added;
    late List<(List<ImportedDialogue>, int)> dialoguesAdded;
    late String sessionId;

    Future<void> pumpHost(WidgetTester tester, {required bool setting}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(
          {DialoguesSettingNotifier.prefsKey: setting, 'subtitle_translator': 'ai'});
      service = FakeSubtitleWords();
      added = [];
      dialoguesAdded = [];
      sessionId = 'session-A';
      final container = ProviderContainer(
          overrides: [subtitleWordsServiceProvider.overrideWithValue(service)]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => runSubtitleImport(
                  context: context,
                  ref: ref,
                  currentSessionId: () => sessionId,
                  sessionWords: () => const [],
                  addWords: (words, _) => added.addAll(words),
                  addDialogues: (d, n) => dialoguesAdded.add((d, n)),
                  pickFile: () async => file(),
                ),
                child: const Text('import'),
              ),
            ),
          ),
        ),
      ));
    }

    Future<void> startImport(WidgetTester tester) async {
      await tester.tap(find.text('import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    const dialogue = (lines: ['I was reluctant to leave.'], words: ['reluctant']);

    testWidgets('setting on: asks for dialogues; Done adds words, then dialogues (AC-02)',
        (tester) async {
      await pumpHost(tester, setting: true);
      await startImport(tester);
      expect(service.asked, [true]);

      service.pending!.complete(result(['reluctant', 'fog'], [dialogue]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(added.map((w) => w.word), ['reluctant', 'fog']);
      expect(dialoguesAdded.single.$1.single.lines, dialogue.lines);
      expect(dialoguesAdded.single.$2, 2);
    });

    testWidgets('setting off: no dialogues asked, Done adds only words (AC-01)',
        (tester) async {
      await pumpHost(tester, setting: false);
      await startImport(tester);
      expect(service.asked, [false]);

      service.pending!.complete(result(['reluctant'], const []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(added.map((w) => w.word), ['reluctant']);
      expect(dialoguesAdded, isEmpty);
    });

    testWidgets('no dialogue qualifies: only words (AC-07)', (tester) async {
      await pumpHost(tester, setting: true);
      await startImport(tester);
      service.pending!.complete(result(['reluctant'], const []));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(added, hasLength(1));
      expect(dialoguesAdded, isEmpty);
    });

    testWidgets('a failure adds neither (AC-08)', (tester) async {
      await pumpHost(tester, setting: true);
      await startImport(tester);
      service.pending!.completeError(
          SubtitleWordsException(SubtitleWordsError.notPicked, 'cut off'));
      await tester.pumpAndSettle();

      expect(find.text(SubtitleImportMessages.notPicked), findsOneWidget);
      expect(added, isEmpty);
      expect(dialoguesAdded, isEmpty);
    });

    testWidgets('a changed session drops words and dialogues (AC-12)',
        (tester) async {
      await pumpHost(tester, setting: true);
      await startImport(tester);
      sessionId = 'session-B';
      service.pending!.complete(result(['reluctant'], [dialogue]));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsNothing);
      expect(added, isEmpty);
      expect(dialoguesAdded, isEmpty);
    });
  });

  group('WordInputNotifier.addImportDialogues', () {
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
    late SessionStore store;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('subtitle_import_dialogues_test');
      store = await SessionStore.open(directory: dir.path);
      container = ProviderContainer(
          overrides: [sessionStoreProvider.overrideWith((ref) async => store)]);
    });

    tearDown(() async {
      container.dispose();
      await store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    WordPair pair(String word, [String rowId = '']) =>
        WordPair(word: word, translation: 'т', rowId: rowId);

    Future<WordInputNotifier> current(Session s) async {
      s.lastLocalModifiedAt = DateTime.now();
      await store.put(s);
      await store.setCurrentSessionId(s.sessionId);
      await container.read(wordInputNotifierProvider.future);
      return container.read(wordInputNotifierProvider.notifier);
    }

    test('links the import\'s rows, drops removed words, appends after the existing (AC-03, AC-10)',
        () async {
      final existing = FilmDialogue()
        ..id = 'old'
        ..lines = ['tide']
        ..wordRowIds = ['r0'];
      final s = Session.create()
        ..words = [pair('tide', 'r0')]
        ..dialogues = [existing];
      final notifier = await current(s);

      // The learner kept "attic" and "dusty"; "stairs" was removed.
      notifier.addAll([pair('attic'), pair('dusty')]);
      notifier.addImportDialogues([
        (lines: ['The attic stairs.'], words: ['attic', 'stairs']),
        (lines: ['The stairs.'], words: ['stairs']),
        (lines: ['A dusty tide.'], words: ['dusty', 'tide']),
      ], 2);
      await notifier.flush();

      final saved = (await store.byId(s.sessionId))!;
      final ids = {for (final w in saved.words) w.word: w.rowId};
      expect(ids['attic'], isNotEmpty);
      expect(saved.dialogues.map((d) => d.id).first, 'old');
      expect(saved.dialogues, hasLength(3));
      expect(saved.dialogues[1].wordRowIds, [ids['attic']]);
      expect(saved.dialogues[2].wordRowIds, [ids['dusty']],
          reason: 'an older row never joins a new dialogue');
      expect(saved.dialogues[1].pushState, PushState.none);
      expect(saved.dialogues[1].importId, isNull);
    });

    test('a shared session marks them pending with the import id and rows (ADR-0005)',
        () async {
      final s = Session.create()
        ..words = [pair('tide', 'r0')]
        ..publishedId = 'pub'
        ..editToken = 'tok';
      final notifier = await current(s);

      notifier.addAll([pair('attic'), pair('dusty')]);
      notifier.addImportDialogues([
        (lines: ['The attic.'], words: ['attic']),
        (lines: ['So dusty.'], words: ['dusty']),
      ], 2);
      await notifier.flush();

      final saved = (await store.byId(s.sessionId))!;
      final rows = [for (final w in saved.words.skip(1)) w.rowId];
      for (final d in saved.dialogues) {
        expect(d.pushState, PushState.pending);
        expect(d.importId, isNotNull);
        expect(d.importRowIds, rows);
      }
      expect(saved.dialogues[0].importId, saved.dialogues[1].importId);
    });

    test('nothing kept: the session is unchanged', () async {
      final s = Session.create()..words = [pair('tide', 'r0')];
      final notifier = await current(s);
      notifier.addAll([pair('attic')]);
      notifier.addImportDialogues([
        (lines: ['The cellar.'], words: ['cellar']),
      ], 1);
      await notifier.flush();
      expect((await store.byId(s.sessionId))!.dialogues, isEmpty);
    });
  });
}
