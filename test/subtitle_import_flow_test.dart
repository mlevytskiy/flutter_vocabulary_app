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
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_google_words.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_search_service.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/subtitle_search_dialog.dart';
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
    required List<String> words,
    required Map<String, String> contexts,
    required List<String> lines,
    required int maximum,
    required SubtitleModel model,
    required List<String> sessionWords,
    bool dialogues = false,
  }) {
    calls.add({'words': words, 'contexts': contexts, 'lines': lines, 'maximum': maximum, 'model': model, 'sessionWords': sessionWords});
    pending = Completer();
    return pending!.future;
  }
}

class FakeGoogleWords extends SubtitleGoogleWords {
  FakeGoogleWords() : super(GoogleTranslateService());
  final calls = <({List<String> words, Map<String, String> contexts, int maximum})>[];

  @override
  Future<List<VocabWord>> translate(List<String> words, {required Map<String, String> contexts, required int maximum}) async {
    calls.add((words: words, contexts: contexts, maximum: maximum));
    return [for (final w in words.take(maximum)) VocabWord(word: w, translation: 'г-$w', context: contexts[w])];
  }
}

class FakeSearch extends SubtitleSearchService {
  SubtitleSearchError? failDownload;

  /// The title suggestions the poster lookup gets, and its queries.
  List<SubtitleTitle> titleResults = const [];
  final titleQueries = <String>[];

  @override
  Future<List<SubtitleTitle>> titles(String query) async {
    titleQueries.add(query);
    return titleResults;
  }

  @override
  Future<List<SubtitleSearchResult>> search(String query, {SubtitleTitle? title, int? season, int? episode}) async {
    return const [
        SubtitleSearchResult(
            fileId: 11, title: 'Harbour Lights', year: 2024, release: 'Release.11', downloads: 9, hearingImpaired: false,
            imageUrl: 'https://posters.test/501.jpg'),
      ];
  }

  @override
  Future<({String fileName, Uint8List bytes})> download(int fileId) async {
    if (failDownload != null) throw SubtitleSearchException(failDownload!, 'test');
    return (fileName: 'Release.11.srt', bytes: Uint8List.fromList(utf8.encode(srtText)));
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
  late FakeGoogleWords google;
  late FakeSearch search;
  late List<VocabWord> added;
  late List<String> films;
  late List<String?> posters;
  late String sessionId;
  late ProviderContainer container;

  Future<void> pumpHost(WidgetTester tester, {XFile? pick, Map<String, Object> prefs = const {}}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'subtitle_translator': 'ai', ...prefs});
    service = FakeSubtitleWords();
    google = FakeGoogleWords();
    search = FakeSearch();
    added = [];
    films = [];
    posters = [];
    sessionId = 'session-A';
    container = ProviderContainer(overrides: [
      subtitleWordsServiceProvider.overrideWithValue(service),
      subtitleGoogleWordsProvider.overrideWithValue(google),
      subtitleSearchServiceProvider.overrideWithValue(search),
    ]);
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
                addWords: (words, film, poster) {
                  added.addAll(words);
                  films.add(film);
                  posters.add(poster);
                },
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

  const loading = 'Translating the words…';

  testWidgets('happy path: loading, then the results dialog; Done appends the kept words in order (AC-02, AC-03)', (tester) async {
    await pumpHost(tester);
    await startImport(tester);

    expect(find.text('Words from subtitles'), findsNothing, reason: 'the import dialog closed');
    expect(find.text(loading), findsOneWidget);
    expect(service.calls.single['words'], ['reluctant'], reason: 'picked on the phone, everyday words ignored');
    expect(service.calls.single['contexts'], {'reluctant': 'I was reluctant to leave.'});
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
    expect(films, ['film'], reason: 'side-panel-sources AC-22: a picked file is named by its file name');
    expect(posters, [null], reason: 'a picked file whose name finds no poster');
    expect(search.titleQueries, ['film'], reason: 'looked up by the file name');
  });

  testWidgets('a picked file gets the poster its name finds (owner, 2026-10-15)', (tester) async {
    await pumpHost(tester);
    search.titleResults = const [
      SubtitleTitle(featureId: 1, title: 'Film', series: false),
      SubtitleTitle(featureId: 2, title: 'Film 2', series: false, imageUrl: 'https://posters.test/77.jpg'),
    ];
    await startImport(tester);
    service.pending!.complete(result(['reluctant']));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(posters, ['https://posters.test/77.jpg'], reason: 'the first suggestion with a poster');
  });

  group('the film name in a file name', () {
    for (final (file, query) in [
      ('The.Office.S01E02.720p.WEBRip', 'The Office'),
      ('Inception (2010) [YIFY]', 'Inception'),
      ('Harbour_Lights_2024_1080p_BluRay_x264', 'Harbour Lights'),
      ('my brilliant friend 1x03', 'my brilliant friend'),
      ('film', 'film'),
      ('2012', '2012'),
    ]) {
      test('"$file" → "$query"', () => expect(subtitlePosterQuery(file), query));
    }
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
    expect(service.calls.single.containsKey('level'), isFalse, reason: 'the level is not sent');
    expect(container.read(subtitleImportPrefsProvider).level, EnglishLevel.c1);
    service.pending!.complete(result([]));
    await tester.pumpAndSettle();
  });

  testWidgets('Update with each import off: Settings keep their values (AC-05b)', (tester) async {
    await pumpHost(tester, prefs: {'subtitle_update_each_import': false});
    await startImport(tester, level: 'C1');
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

  testWidgets('Google Translate chosen: the phone picks, Google translates, the context is the phone\'s line; the Worker is not called', (tester) async {
    await pumpHost(tester, prefs: {'subtitle_translator': 'google'});
    await startImport(tester);
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);
    expect(google.calls.single.words, ['reluctant']);
    expect(google.calls.single.maximum, 20);
    expect(find.text('reluctant'), findsOneWidget);
    expect(find.text('Context: I was reluctant to leave.'), findsOneWidget);
    expect(find.textContaining('Definition'), findsNothing);
    expect(find.textContaining('Google Translate · '), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(added.single.translation, 'г-reluctant');
  });

  testWidgets('AI via OpenCode chosen: the Worker is asked with the OpenCode model, and the cost line names it', (tester) async {
    await pumpHost(tester, prefs: {'subtitle_translator': 'opencode', 'subtitle_opencode_model': 'deepseekV41Flash'});
    await startImport(tester);
    expect(service.calls.single['model'], SubtitleModel.deepseekV41Flash);
    expect(google.calls, isEmpty);
    service.pending!.complete(result(['reluctant'], model: SubtitleModel.deepseekV41Flash));
    await tester.pumpAndSettle();
    expect(find.textContaining('DeepSeek V4.1 Flash · '), findsOneWidget);
  });

  testWidgets('the close-repeat setting reaches the word picker', (tester) async {
    // "fog" twice in one scene (score 2 + 3 = 5) against "lantern" three times far apart (score 3).
    final cues = [
      for (final (i, text) in ['The lantern.', 'Fog.', 'Fog again.', 'Okay.', 'Okay.', 'Okay.', 'The lantern.', 'Okay.', 'Okay.', 'Okay.', 'The lantern.'].indexed)
        '${i + 1}\n00:00:${(i * 2).toString().padLeft(2, '0')},000 --> 00:00:${(i * 2 + 1).toString().padLeft(2, '0')},000\n$text\n',
    ].join('\n');
    for (final (on, first) in [(true, 'fog'), (false, 'lantern')]) {
      await pumpHost(tester, pick: file(cues), prefs: {'subtitle_translator': 'google', 'subtitle_boost_close_repeats': on, 'subtitle_level': 'A1'});
      await startImport(tester);
      await tester.pumpAndSettle();
      expect(google.calls.single.words.first, first, reason: 'boost $on');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the remove-names setting reaches the word picker', (tester) async {
    const cues = '1\n00:00:01,000 --> 00:00:02,000\nCall Ophelia, the drizzle stopped.\n';
    for (final (on, words) in [(true, ['drizzle']), (false, ['ophelia', 'drizzle'])]) {
      await pumpHost(tester, pick: file(cues), prefs: {'subtitle_translator': 'google', 'subtitle_remove_names': on, 'subtitle_level': 'A1'});
      await startImport(tester);
      await tester.pumpAndSettle();
      expect(google.calls.single.words, containsAll(words), reason: 'remove names $on');
      if (on) expect(google.calls.single.words, isNot(contains('ophelia')));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('while the translation runs, the picked words show with their context lines and skeleton translations', (tester) async {
    await pumpHost(tester);
    await startImport(tester);
    expect(find.text(loading), findsOneWidget);
    expect(find.text('film.srt'), findsOneWidget);
    expect(find.text('reluctant'), findsOneWidget);
    expect(find.text('“I was reluctant to leave.”'), findsOneWidget);
    expect(find.byKey(const Key('subtitle-card-skeleton')), findsOneWidget);
    service.pending!.complete(result(['reluctant']));
    await tester.pump();
    await tester.pump();
    expect(find.text('т-reluctant'), findsOneWidget, reason: 'the card fills in');
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget, reason: 'then the results dialog');
  });

  testWidgets('Cancel in the progress dialog ends the import without the results dialog', (tester) async {
    await pumpHost(tester);
    await startImport(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text(loading), findsNothing);
    service.pending!.complete(result(['reluctant']));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    expect(added, isEmpty);
  });

  Future<void> startFoundByName(WidgetTester tester) async {
    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find by name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), 'harbour lights');
    await tester.pump();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harbour Lights (2024)'));
    await tester.pumpAndSettle();
    expect(find.text('Harbour Lights (2024)'), findsOneWidget, reason: 'back in the import dialog with the title');
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a file found by name: its title goes through the progress dialog to the results dialog', (tester) async {
    await pumpHost(tester);
    await startFoundByName(tester);
    expect(find.text(loading), findsOneWidget);
    expect(find.text('Harbour Lights (2024)'), findsOneWidget);
    expect(find.text('reluctant'), findsOneWidget);
    service.pending!.complete(result(['reluctant']));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Harbour Lights (2024)'), findsOneWidget, reason: 'the results dialog names the film');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(films, ['Harbour Lights (2024)'], reason: 'side-panel-sources AC-22: the rows go under the film found by name');
    expect(posters, ['https://posters.test/501.jpg'], reason: 'the poster rides with the film for the panel tile');
  });

  testWidgets('a file found by name that fails to download says why, and adds nothing', (tester) async {
    await pumpHost(tester);
    search.failDownload = SubtitleSearchError.downloadLimit;
    await startFoundByName(tester);
    await tester.pumpAndSettle();
    expect(find.text(SubtitleSearchMessages.downloadLimit), findsOneWidget);
    expect(service.calls, isEmpty);
    expect(added, isEmpty);
  });

  testWidgets('a file of only everyday words is refused on the phone with the AC-10 message', (tester) async {
    await pumpHost(tester, pick: file('1\n00:00:01,000 --> 00:00:03,000\nI know what you want.\n'));
    await startImport(tester);
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);
    expect(find.text(SubtitleImportMessages.noEnglish), findsOneWidget);
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

  testWidgets('the speed dial offers From subtitles next to Get words from photo', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        floatingActionButton: WordInputSpeedDial(
          onTakePhoto: () {},
          onFromSubtitles: () => tapped = true,
          onImportFromQuizlet: () {},
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Get words from photo'), findsOneWidget);
    expect(find.text('Screenshot'), findsNothing);
    await tester.tap(find.text('From subtitles'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
