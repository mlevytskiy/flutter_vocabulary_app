import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_search_service.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/subtitle_import_dialog.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/subtitle_search_dialog.dart';

class FakeSearch extends SubtitleSearchService {
  final searched = <String>[];
  final suggestedFor = <String>[];
  final byTitle = <({int featureId, int? season, int? episode})>[];

  static const film = SubtitleTitle(featureId: 501, title: 'Harbour Lights', year: 2024, series: false);
  static const show = SubtitleTitle(
    featureId: 502,
    title: 'Harbour Lights',
    year: 2025,
    series: true,
    seasons: [(season: 1, episodes: 4), (season: 2, episodes: 2)],
  );

  @override
  Future<List<SubtitleTitle>> titles(String query) async {
    suggestedFor.add(query);
    return const [film, show];
  }
  SubtitleSearchError? failSearch;
  SubtitleSearchError? failDownload;
  final downloaded = <int>[];

  /// Holds downloads until released, to show nothing waits for them.
  Completer<void>? hold;

  @override
  Future<List<SubtitleSearchResult>> search(String query, {SubtitleTitle? title, int? season, int? episode}) async {
    if (title != null) byTitle.add((featureId: title.featureId, season: season, episode: episode));
    searched.add(query);
    if (failSearch != null) throw SubtitleSearchException(failSearch!, 'test');
    if (query.contains('nothing')) return const [];
    return const [
      SubtitleSearchResult(
          fileId: 11, title: 'Harbour Lights', year: 2024, release: 'Release.11', downloads: 1011, hearingImpaired: false,
          imageUrl: 'https://posters.test/501.jpg'),
      SubtitleSearchResult(
          fileId: 12, title: 'The Storm', show: 'Harbour Lights', season: 1, episode: 4,
          release: 'Release.12', downloads: 1012, hearingImpaired: true),
    ];
  }

  @override
  Future<({String fileName, Uint8List bytes})> download(int fileId) async {
    downloaded.add(fileId);
    await hold?.future;
    if (failDownload != null) throw SubtitleSearchException(failDownload!, 'test');
    return (fileName: 'Release.$fileId.srt', bytes: Uint8List.fromList(utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nFog.\n')));
  }
}

/// Finding a subtitle file by name: the search dialog, and "Find by name" in
/// the import dialog.
void main() {
  late FakeSearch service;
  SubtitleSource? picked;
  var closed = false;

  Future<void> openSearch(WidgetTester tester) async {
    service = FakeSearch();
    picked = null;
    closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            picked = await showSubtitleSearchDialog(context, service: service);
            closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> searchFor(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), name);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('a name finds films and episodes with their release, downloads and hearing-impaired mark', (tester) async {
    await openSearch(tester);
    expect(find.text(SubtitleSearchMessages.hint), findsOneWidget);
    await searchFor(tester, 'harbour lights');
    expect(service.searched, ['harbour lights']);
    expect(find.text('Harbour Lights (2024)'), findsOneWidget);
    expect(find.text('Harbour Lights · S01E04 · The Storm'), findsOneWidget);
    expect(find.text('Release.11 · 1011 downloads'), findsOneWidget);
    expect(find.text('Release.12 · 1012 downloads · for the hard of hearing'), findsOneWidget);
  });

  testWidgets('typing suggests films and series once the learner pauses; picking a series, a season and an episode each search at once', (tester) async {
    await openSearch(tester);
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), 'ha');
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.suggestedFor, isEmpty, reason: 'under 3 letters');
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), 'harb');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), 'harbour');
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.suggestedFor, ['harbour'], reason: 'only after the pause');
    await tester.pumpAndSettle();
    expect(find.text('Harbour Lights (2024)'), findsOneWidget);
    expect(find.text('Film'), findsOneWidget);
    expect(find.text('Series · 2 seasons'), findsOneWidget);

    await tester.tap(find.text('Series · 2 seasons'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subtitle-search-suggestions')), findsNothing);
    expect(find.widgetWithText(TextField, 'Harbour Lights (2025)'), findsOneWidget);
    expect(service.byTitle, [(featureId: 502, season: null, episode: null)], reason: 'picking the series searches it');
    expect(find.text('Harbour Lights (2024)'), findsOneWidget, reason: 'its results are shown');

    await tester.tap(find.byKey(const Key('subtitle-search-season')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();
    expect(service.byTitle.last, (featureId: 502, season: 1, episode: null), reason: 'the season searches at once');

    await tester.tap(find.byKey(const Key('subtitle-search-episode')));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsWidgets, reason: 'season 1 has 4 episodes');
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();
    expect(service.byTitle.last, (featureId: 502, season: 1, episode: 4), reason: 'the episode searches at once');
    expect(service.byTitle, hasLength(3), reason: 'no Search tap needed');
  });

  testWidgets('a picked film searches by its title, with no season or episode', (tester) async {
    await openSearch(tester);
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), 'harbour');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Film'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subtitle-search-season')), findsNothing);
    expect(service.byTitle, [(featureId: 501, season: null, episode: null)], reason: 'picking the film searches it at once');
  });

  testWidgets('typing after picking drops the suggestion: the typed name is searched as it is', (tester) async {
    await openSearch(tester);
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), 'harbour');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Series · 2 seasons'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('subtitle-search-query')), 'harbour nights');
    await tester.pump();
    expect(find.byKey(const Key('subtitle-search-season')), findsNothing);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(service.byTitle, hasLength(1), reason: 'only the search from picking the series');
    expect(service.searched.last, 'harbour nights');
  });

  testWidgets('one letter does not search', (tester) async {
    await openSearch(tester);
    await searchFor(tester, 'h');
    expect(service.searched, isEmpty);
  });

  testWidgets('tapping a result closes at once with its title and poster; the file downloads behind', (tester) async {
    await openSearch(tester);
    service.hold = Completer();
    await searchFor(tester, 'harbour lights');
    await tester.tap(find.text('Harbour Lights (2024)'));
    await tester.pumpAndSettle();
    expect(closed, isTrue, reason: 'no waiting for the download');
    expect(service.downloaded, [11], reason: 'the download has started');
    expect(picked!.fileName, 'Release.11.srt');
    expect(picked!.title, 'Harbour Lights (2024)');
    expect(picked!.imageUrl, 'https://posters.test/501.jpg');
    service.hold!.complete();
    expect(utf8.decode(await picked!.bytes), contains('Fog.'));
  });

  testWidgets('nothing found and a failed search each say so, and the dialog stays', (tester) async {
    await openSearch(tester);
    await searchFor(tester, 'nothing at all');
    expect(find.text(SubtitleSearchMessages.nothingFound), findsOneWidget);

    service.failSearch = SubtitleSearchError.unavailable;
    await searchFor(tester, 'harbour');
    expect(find.text(SubtitleSearchMessages.unavailable), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('Cancel closes it with no file', (tester) async {
    await openSearch(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(picked, isNull);
  });

  testWidgets('the import dialog offers Find by name; the found file shows its title and Start works before it has downloaded', (tester) async {
    SubtitleImportRequest? request;
    final download = Completer<Uint8List>();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => request = await showSubtitleImportDialog(
            context,
            initial: SubtitleImportPrefs.firstLaunch,
            pickFile: () async => null,
            findByName: (context) async => SubtitleSource(
              fileName: 'Release.12.srt',
              bytes: download.future,
              title: 'Harbour Lights · S01E04 · The Storm',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose file'), findsOneWidget);
    await tester.tap(find.text('Find by name'));
    await tester.pumpAndSettle();
    expect(find.text('Harbour Lights · S01E04 · The Storm'), findsOneWidget);
    expect(find.text('Release.12.srt'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(request!.fileName, 'Release.12.srt', reason: 'Start did not wait for the download');
    expect(request!.title, 'Harbour Lights · S01E04 · The Storm');
    download.complete(Uint8List.fromList(utf8.encode('found')));
    expect(utf8.decode(await request!.bytes), 'found');
  });

  testWidgets('without findByName there is no Find by name button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSubtitleImportDialog(context, initial: SubtitleImportPrefs.firstLaunch, pickFile: () async => null),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Find by name'), findsNothing);
  });
}
