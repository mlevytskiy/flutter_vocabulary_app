// word-context T8: a film row keeps the film's name, season and episode
// (from the search result picked, or from the file's name), the time its word
// is first said and the line sent for it as its context (AC-06 – AC-09).
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_google_words.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_search_service.dart';
import 'package:flutter_vocabulary_app/features/words/subtitle_import_flow.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/subtitle_import_dialog.dart';

const srt = '1\n00:00:01,000 --> 00:00:03,000\nHello there.\n\n'
    '2\n00:01:02,500 --> 00:01:04,000\nI was reluctant to leave.\n\n'
    '3\n01:00:05,000 --> 01:00:07,000\n- Still reluctant?\n- Always.\n';

class FakeGoogleWords extends SubtitleGoogleWords {
  FakeGoogleWords() : super(GoogleTranslateService());

  @override
  Future<List<VocabWord>> translate(List<String> words,
          {required Map<String, String> contexts, required int maximum}) async =>
      [for (final w in words.take(maximum)) VocabWord(word: w, translation: 'т-$w')];
}

class FakeSearch extends SubtitleSearchService {
  @override
  Future<List<SubtitleTitle>> titles(String query) async => const [];

  @override
  Future<List<SubtitleSearchResult>> search(String query, {SubtitleTitle? title, int? season, int? episode}) async =>
      const [
        SubtitleSearchResult(
            fileId: 7,
            title: 'The Storm',
            show: 'Harbour Lights',
            season: 2,
            episode: 5,
            release: 'Harbour.Lights.S02E05',
            downloads: 3,
            hearingImpaired: false),
      ];

  @override
  Future<({String fileName, Uint8List bytes})> download(int fileId) async =>
      (fileName: 'Harbour.Lights.S02E05.srt', bytes: Uint8List.fromList(utf8.encode(srt)));
}

void main() {
  late List<WordPair> rows;
  late List<String> films;

  Future<void> pumpHost(WidgetTester tester, {required String fileName}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'subtitle_translator': 'google'});
    rows = [];
    films = [];
    final container = ProviderContainer(overrides: [
      subtitleGoogleWordsProvider.overrideWithValue(FakeGoogleWords()),
      subtitleSearchServiceProvider.overrideWithValue(FakeSearch()),
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
                currentCollectionId: () => 'c',
                collectionWords: () => const [],
                addWords: (words, film, poster, filmRow) {
                  films.add(film);
                  rows.addAll([for (final w in words) filmRow(WordPair(word: w.word))]);
                },
                pickFile: () async =>
                    XFile.fromData(Uint8List.fromList(utf8.encode(srt)), name: fileName, path: fileName),
              ),
              child: const Text('import'),
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  WordPair row(String word) => rows.singleWhere((r) => r.word == word);

  testWidgets(
      'a file opened by the learner: its name, season and episode from the file name, '
      'the time of the first line with the word, the line sent as context (AC-07 – AC-09)', (tester) async {
    await pumpHost(tester, fileName: 'Harbour.Lights.s2e5.720p.srt');
    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await finish(tester);

    final r = row('reluctant');
    expect(films, ['Harbour.Lights.s2e5.720p']);
    expect(r.origin.typeOfSource, SourceType.movie);
    expect(r.origin.movieName, 'Harbour.Lights.s2e5.720p');
    expect(r.origin.season, 2);
    expect(r.origin.episode, 5);
    expect(r.origin.time, '00:01:02');
    expect(r.context, contains('I was reluctant to leave.'));
    expect(r.context, r.context.trim());
    expect(r.contextKind, ContextKind.source);
  });

  testWidgets('a file with no episode mark: season and episode stay empty (AC-07)', (tester) async {
    await pumpHost(tester, fileName: 'harbour.srt');
    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await finish(tester);

    final r = row('reluctant');
    expect(r.origin.movieName, 'harbour');
    expect(r.origin.season, isNull);
    expect(r.origin.episode, isNull);
  });

  testWidgets('a film found by name: the series name, season and episode of the result picked (AC-06)', (tester) async {
    await pumpHost(tester, fileName: 'unused.srt');
    await tester.tap(find.text('import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find by name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), 'harbour lights');
    await tester.pump();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harbour Lights · S02E05 · The Storm'));
    await tester.pumpAndSettle();
    await finish(tester);

    final r = row('reluctant');
    expect(r.origin.typeOfSource, SourceType.movie);
    expect(r.origin.movieName, 'Harbour Lights');
    expect(r.origin.season, 2);
    expect(r.origin.episode, 5);
    expect(r.origin.time, '00:01:02');
    expect(r.contextKind, ContextKind.source);
  });

  group('subtitleOrigin', () {
    SubtitleImportRequest request(String fileName, {SubtitleSearchResult? found}) => SubtitleImportRequest(
          fileName: fileName,
          bytes: Future.value(Uint8List(0)),
          level: EnglishLevel.b1,
          maximum: 20,
          title: found?.label,
          found: found,
        );

    test('a found film (no series) is named by its title, no season or episode', () {
      final origin = subtitleOrigin(request('Release.srt',
          found: const SubtitleSearchResult(
              fileId: 1, title: 'Harbour Lights', year: 2024, release: 'R', downloads: 1, hearingImpaired: false)));
      expect(origin.typeOfSource, SourceType.movie);
      expect(origin.movieName, 'Harbour Lights');
      expect(origin.season, isNull);
      expect(origin.episode, isNull);
    });

    test('a found result never reads the file name for the episode', () {
      final origin = subtitleOrigin(request('Show.S09E09.srt',
          found: const SubtitleSearchResult(
              fileId: 1, title: 'Pilot', show: 'Show', release: 'R', downloads: 1, hearingImpaired: false)));
      expect(origin.movieName, 'Show');
      expect(origin.season, isNull);
      expect(origin.episode, isNull);
    });

    test('a file: 2x05 in its name', () {
      final origin = subtitleOrigin(request('Show 2x05.vtt'));
      expect(origin.movieName, 'Show 2x05');
      expect((origin.season, origin.episode), (2, 5));
    });
  });

  group('subtitleFilmRow', () {
    final origin = WordOrigin()
      ..typeOfSource = SourceType.movie
      ..movieName = 'Film';
    const lines = [
      (start: Duration(seconds: 5), text: 'Hello there.'),
      (start: Duration(hours: 1, minutes: 2, seconds: 3), text: 'The Harbour was empty.'),
    ];

    test('time of the first line with the whole word; context trimmed, kind source; origin copied', () {
      final r = subtitleFilmRow(WordPair(word: 'harbour'),
          origin: origin, contexts: {'harbour': '  The Harbour was empty.  '}, lines: lines);
      expect(r.origin.time, '01:02:03');
      expect(r.origin.movieName, 'Film');
      expect(identical(r.origin, origin), isFalse);
      expect(origin.time, '', reason: 'the shared origin is not changed');
      expect(r.context, 'The Harbour was empty.');
      expect(r.contextKind, ContextKind.source);
    });

    test('a word the AI returned capitalised still finds its line', () {
      final r = subtitleFilmRow(WordPair(word: 'Harbour'),
          origin: origin, contexts: {'harbour': 'The Harbour was empty.'}, lines: lines);
      expect(r.context, 'The Harbour was empty.');
    });

    test('no line and no context: empty time, empty context, kind none', () {
      final r = subtitleFilmRow(WordPair(word: 'harb'), origin: origin, contexts: const {}, lines: lines);
      expect(r.origin.time, '');
      expect(r.context, '');
      expect(r.contextKind, ContextKind.none);
    });
  });
}
