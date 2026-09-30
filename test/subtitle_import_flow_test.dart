import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_words_service.dart';
import 'package:flutter_vocabulary_app/features/word_input/subtitle_import_flow.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_input_speed_dial.dart';

/// words-from-subtitles T11: the From subtitles flow — speed dial, import
/// dialog, parse, request, loading, results, Done (sad §6 F3 and F4).
class FakeSubtitleWords extends SubtitleWordsService {
  final calls = <Map<String, Object>>[];
  Completer<SubtitleWordsResult>? pending;

  @override
  Future<SubtitleWordsResult> pickWords({
    required List<String> lines,
    required ImportPurpose purpose,
    required EnglishLevel level,
    required int maximum,
    required SubtitleModel model,
    required List<String> sessionWords,
  }) {
    calls.add({'lines': lines, 'purpose': purpose, 'level': level, 'maximum': maximum, 'model': model, 'sessionWords': sessionWords});
    pending = Completer();
    return pending!.future;
  }
}

SubtitleWordsResult result(List<String> words, {SubtitleModel model = SubtitleModel.sonnet5}) => SubtitleWordsResult(
      words: [for (final w in words) VocabWord(word: w, translation: 'т-$w', description: 'd-$w', context: 'c-$w')],
      model: model,
      aiDuration: const Duration(seconds: 3),
      inputTokens: 30000,
      outputTokens: 2000,
    );

const srtText = '1\n00:00:01,000 --> 00:00:03,000\nI was reluctant to leave.\n\n2\n00:00:04,000 --> 00:00:05,000\n[door slams]\n';

XFile file(String text, [String name = 'film.srt']) =>
    XFile.fromData(Uint8List.fromList(utf8.encode(text)), name: name, path: name);

void main() {
  late FakeSubtitleWords service;
  late List<VocabWord> added;
  late String sessionId;
  late ProviderContainer container;

  Future<void> pumpHost(WidgetTester tester, {XFile? pick, Map<String, Object> prefs = const {}}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    service = FakeSubtitleWords();
    added = [];
    sessionId = 'session-A';
    container = ProviderContainer(overrides: [subtitleWordsServiceProvider.overrideWithValue(service)]);
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
                sessionWords: () => ['tide'],
                addWords: added.addAll,
                pickFile: () async => pick ?? file(srtText),
              ),
              child: const Text('import'),
            ),
          ),
        ),
      ),
    ));
  }

  /// Opens the import dialog, picks the file, optionally sets the level, taps Start.
  Future<void> startImport(WidgetTester tester, {String? level}) async {
    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    if (level != null) {
      await tester.tap(find.byType(DropdownButton<EnglishLevel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(level).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  const loading = 'Picking words from the subtitles…';

  testWidgets('happy path: loading, then the results dialog; Done appends the kept words in order (AC-02, AC-03)', (tester) async {
    await pumpHost(tester);
    await startImport(tester);

    expect(find.text('Words from subtitles'), findsNothing, reason: 'the import dialog closed');
    expect(find.text(loading), findsOneWidget);
    expect(service.calls.single['lines'], ['I was reluctant to leave.']);
    expect(service.calls.single['sessionWords'], ['tide']);
    expect(service.calls.single['model'], SubtitleModel.sonnet5);
    expect(service.calls.single['maximum'], 20);

    service.pending!.complete(result(['reluctant', 'harbour', 'fog']));
    await tester.pumpAndSettle();
    expect(find.text(loading), findsNothing);
    expect(find.text('reluctant'), findsOneWidget);
    expect(find.text('Definition: d-reluctant'), findsOneWidget);
    expect(find.text('Context: c-reluctant'), findsOneWidget);
    expect(find.textContaining('Sonnet 5 · '), findsOneWidget);

    await tester.tap(find.byTooltip('Skip this word').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(added.map((w) => w.word), ['reluctant', 'fog']);
  });

  testWidgets('removing every word, or closing, adds nothing (AC-04)', (tester) async {
    await pumpHost(tester);
    await startImport(tester);
    service.pending!.complete(result(['reluctant']));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skip this word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(added, isEmpty);
  });

  testWidgets('no word qualifies: the empty message, and Done adds nothing (AC-20)', (tester) async {
    await pumpHost(tester);
    await startImport(tester);
    service.pending!.complete(result([]));
    await tester.pumpAndSettle();
    expect(find.text('No new words above your level in these subtitles.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(added, isEmpty);
  });

  testWidgets('Update with each import on: the values used become the Settings values (AC-05)', (tester) async {
    await pumpHost(tester);
    await startImport(tester, level: 'C1');
    expect(service.calls.single['level'], EnglishLevel.c1);
    expect(container.read(subtitleImportPrefsProvider).level, EnglishLevel.c1);
    service.pending!.complete(result([]));
    await tester.pumpAndSettle();
  });

  testWidgets('Update with each import off: Settings keep their values (AC-05b)', (tester) async {
    await pumpHost(tester, prefs: {'subtitle_update_each_import': false});
    await startImport(tester, level: 'C1');
    expect(service.calls.single['level'], EnglishLevel.c1);
    expect(container.read(subtitleImportPrefsProvider).level, EnglishLevel.b2);
    service.pending!.complete(result([]));
    await tester.pumpAndSettle();
  });

  testWidgets('a file with no subtitle blocks, or not srt/vtt, is refused on the phone with the AC-10 message', (tester) async {
    for (final f in [file('Just text, no timings.'), file(srtText, 'film.txt')]) {
      await pumpHost(tester, pick: f);
      await startImport(tester);
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
      expect(find.text(loading), findsNothing);
      expect(find.text(SubtitleImportMessages.noEnglish), findsOneWidget);
      expect(added, isEmpty);
    }
  });

  for (final (error, message) in [
    (SubtitleWordsError.noEnglish, SubtitleImportMessages.noEnglish),
    (SubtitleWordsError.tooManyImports, SubtitleImportMessages.tooManyImports),
    (SubtitleWordsError.notPicked, SubtitleImportMessages.notPicked),
  ]) {
    testWidgets('${error.name}: the loading dialog closes with its message and nothing is added (AC-10, AC-12, AC-14)', (tester) async {
      await pumpHost(tester);
      await startImport(tester);
      service.pending!.completeError(SubtitleWordsException(error, 'test'));
      await tester.pumpAndSettle();
      expect(find.text(loading), findsNothing);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(added, isEmpty);
    });
  }

  testWidgets('the messages are the spec wording', (tester) async {
    expect(SubtitleImportMessages.noEnglish, 'No English subtitles to read in this file.');
    expect(SubtitleImportMessages.tooManyImports, 'Too many subtitle imports. Wait a few minutes and try again.');
    expect(SubtitleImportMessages.notPicked, "The words couldn't be picked. Try again from the + button.");
  });

  testWidgets('a list longer than the maximum is not shown (spec §6 Word maximum respected)', (tester) async {
    await pumpHost(tester, prefs: {'subtitle_maximum': 2});
    await startImport(tester);
    expect(service.calls.single['maximum'], 2);
    service.pending!.complete(result(['a', 'b', 'c']));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    expect(find.text(SubtitleImportMessages.notPicked), findsOneWidget);
    expect(added, isEmpty);
  });

  testWidgets('a result for a session that changed since Start is dropped (AC-16)', (tester) async {
    await pumpHost(tester);
    await startImport(tester);
    sessionId = 'session-B';
    service.pending!.complete(result(['reluctant']));
    await tester.pumpAndSettle();
    expect(find.text(loading), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(added, isEmpty);
  });

  testWidgets('the speed dial offers From subtitles next to Take Photo', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        floatingActionButton: WordInputSpeedDial(
          onTakePhoto: () {},
          onScreenshot: () {},
          onFromSubtitles: () => tapped = true,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Take Photo'), findsOneWidget);
    await tester.tap(find.text('From subtitles'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
