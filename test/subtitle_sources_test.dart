import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_publish_service.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photos_with_words.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/source_tile.dart';
import 'package:flutter_vocabulary_app/features/word_input/subtitle_import_flow.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/subtitle_import_dialog.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

import 'photo_panel_test_host.dart';

/// side-panel-sources AC-22: words from film subtitles are a source of their
/// own, listed in the half-open panel like a Quizlet set, and never declared
/// to the Worker.
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

  SourceWithWords fakeFilm(String id, {String name = 'Film', int at = 0, List<int> rows = const [40]}) => (
        source: SessionSource()
          ..id = id
          ..kind = SourceKind.subtitles
          ..name = name
          ..takenAt = DateTime(2026, 10, 13, 9, at),
        rows: rows,
      );

  group('the model', () {
    test('subtitles is appended: photo and set keep their stored ordinals', () {
      expect(SourceKind.values, [SourceKind.photo, SourceKind.set, SourceKind.subtitles]);
      expect(SourceKind.photo.index, 0);
      expect(SourceKind.set.index, 1);
    });

    test('JSON round trip keeps a film; JSON without kind is still a photo', () {
      final film = SessionSource()
        ..id = 'subtitles-1'
        ..kind = SourceKind.subtitles
        ..name = 'Harbour Lights (2024)';
      final back = SessionSource.fromJson(film.toJson());
      expect([back.kind, back.name, back.url, back.fileName], [SourceKind.subtitles, 'Harbour Lights (2024)', null, '']);
      expect(SessionSource.fromJson({'id': 'a1'}).kind, SourceKind.photo);
    });

    test('Isar: photos and sets read back unchanged next to a film', () async {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory.systemTemp.createTempSync('subtitle_sources_isar');
      final store = await SessionStore.open(directory: dir.path);
      try {
        final session = Session.create()
          ..sources = [
            SessionSource()
              ..id = 'p1'
              ..fileName = 'p1.jpg',
            SessionSource()
              ..id = 'quizlet-1'
              ..kind = SourceKind.set
              ..name = 'Biology'
              ..url = 'https://quizlet.com/1/biology/',
            SessionSource()
              ..id = 'subtitles-1'
              ..kind = SourceKind.subtitles
              ..name = 'Harbour Lights',
          ];
        await store.put(session);
        final back = (await store.byId(session.sessionId))!;
        expect([for (final s in back.sources) '${s.id}|${s.kind.name}|${s.fileName}|${s.name}|${s.url}'], [
          'p1|photo|p1.jpg|null|null',
          'quizlet-1|set||Biology|https://quizlet.com/1/biology/',
          'subtitles-1|subtitles||Harbour Lights|null',
        ]);
      } finally {
        await store.close();
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('recording the film on import', () {
    late Directory dir;
    late SessionStore store;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('subtitle_sources_notifier');
      store = await SessionStore.open(directory: dir.path);
      container = ProviderContainer(overrides: [sessionStoreProvider.overrideWith((ref) async => store)]);
      await container.read(wordInputNotifierProvider.future);
    });

    tearDown(() async {
      container.dispose();
      await store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('one source per film; importing the same film again reuses it', () {
      final notifier = container.read(wordInputNotifierProvider.notifier);
      final a = notifier.upsertSubtitlesSource('Harbour Lights (2024)');
      final b = notifier.upsertSubtitlesSource('The Storm');
      final again = notifier.upsertSubtitlesSource('Harbour Lights (2024)');
      expect(a, startsWith('subtitles-'));
      expect(again, a);
      expect(b, isNot(a));
      final sources = container.read(wordInputNotifierProvider).value!.sources;
      expect([for (final s in sources) '${s.id}|${s.kind.name}|${s.name}'],
          ['$a|subtitles|Harbour Lights (2024)', '$b|subtitles|The Storm']);
      expect(RegExp(r'^[A-Za-z0-9-]{1,64}$').hasMatch(a), isTrue, reason: 'a valid source id');
    });

    test('a Quizlet set with the same name is not reused for a film', () {
      final notifier = container.read(wordInputNotifierProvider.notifier);
      final set = notifier.upsertSetSource('1', 'Harbour', 'https://quizlet.com/1/harbour/');
      expect(notifier.upsertSubtitlesSource('Harbour'), isNot(set));
    });

    test('the film is listed with its rows among the panel sources', () {
      final notifier = container.read(wordInputNotifierProvider.notifier);
      final film = notifier.upsertSubtitlesSource('Harbour Lights');
      notifier.setPairs([
        WordPair(word: 'typed'),
        WordPair(word: 'reluctant', sourceId: film),
        WordPair(word: 'fog', sourceId: film),
      ]);
      final listed = container.read(sourcesWithWordsProvider);
      expect([for (final p in listed) '${p.source.id}:${p.rows.join(',')}'], ['$film:1,2']);
      expect(listed.single.isPhoto, isFalse);
      expect(container.read(photosWithWordsProvider), isEmpty, reason: 'full-open stays photos only');
    });
  });

  group('the film title', () {
    SubtitleImportRequest request(String fileName, {String? title}) => SubtitleImportRequest(
        fileName: fileName,
        bytes: Future.value(Uint8List(0)),
        level: EnglishLevel.values.first,
        maximum: 20,
        title: title);

    test('found by name: the title; picked: the file name without its extension', () {
      expect(subtitleFilmTitle(request('Release.11.srt', title: 'Harbour Lights (2024)')), 'Harbour Lights (2024)');
      expect(subtitleFilmTitle(request('My_Film_S01E04.srt')), 'My_Film_S01E04');
      expect(subtitleFilmTitle(request('noext')), 'noext');
      expect(subtitleFilmTitle(request('.srt')), '.srt');
      expect(subtitleFilmTitle(request('film.srt', title: '  ')), 'film');
    });
  });

  group('publishing', () {
    test('a film is not declared and its rows go without a sourceId', () async {
      final requests = <http.Request>[];
      final service = SessionPublishService(
          client: MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode({'id': 'x', 'url': 'https://e/s/x'}), 200);
      }));
      final published = await service.publish(
        [
          WordPair(word: 'shelf', translation: 'полиця', sourceId: 'p1'),
          WordPair(word: 'fog', translation: 'туман', sourceId: 'subtitles-1'),
        ],
        sources: [
          SessionSource()
            ..id = 'p1'
            ..fileName = 'p1.jpg',
          SessionSource()
            ..id = 'subtitles-1'
            ..kind = SourceKind.subtitles
            ..name = 'Harbour Lights',
        ],
      );
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body['sources'], [
        {'id': 'p1', 'order': 0, 'kind': 'photo'},
      ]);
      expect(body['entries'], [
        {'word': 'shelf', 'translation': 'полиця', 'sourceId': 'p1'},
        {'word': 'fog', 'translation': 'туман'},
      ]);
      expect(published.declaredSources.map((s) => s.id), ['p1']);
    });

    test('a film-only session sends no sources at all', () async {
      final requests = <http.Request>[];
      final service = SessionPublishService(
          client: MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode({'id': 'x', 'url': 'https://e/s/x'}), 200);
      }));
      await service.publish(
        [WordPair(word: 'fog', translation: 'туман', sourceId: 'subtitles-1')],
        sources: [
          SessionSource()
            ..id = 'subtitles-1'
            ..kind = SourceKind.subtitles
            ..name = 'Harbour Lights',
        ],
      );
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes)) as Map;
      expect(body.containsKey('sources'), isFalse);
      expect((body['entries'] as List).single, {'word': 'fog', 'translation': 'туман'});
    });
  });

  group('the tile', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<PanelHost> openHalf(WidgetTester tester, PanelHost host) async {
      await host.pump(tester);
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();
      expect(host.controller.stop, PanelStop.halfOpen);
      return host;
    }

    testWidgets('half-open: a film is a tile the size of a small photo with the film icon and its title',
        (tester) async {
      final photos = fakePhotos(1);
      final host = PanelHost(photos: [
        photos[0],
        fakeFilm('subtitles-1', name: 'A very long film title · S01E04 · The Storm That Never Ends', at: 1),
      ]);
      await openHalf(tester, host);
      expect(tester.getRect(smallPhoto('subtitles-1')).size, tester.getRect(smallPhoto('p0')).size);
      expect(find.descendant(of: smallPhoto('subtitles-1'), matching: find.byIcon(Icons.movie_outlined)), findsOneWidget);
      final name = tester.widget<Text>(
          find.descendant(of: smallPhoto('subtitles-1'), matching: find.byKey(const Key('source-tile-name'))));
      expect(name.data, startsWith('A very long film'));
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(find.byKey(PhotoPanel.largePhotoKey('subtitles-1')), findsNothing);
    });

    testWidgets('tapping a film selects it; a screen reader names it "Film <title>"', (tester) async {
      final handle = tester.ensureSemantics();
      final host = PanelHost(photos: [...fakePhotos(1), fakeFilm('subtitles-1', name: 'Harbour Lights', at: 1)]);
      await openHalf(tester, host);
      final node = tester.getSemantics(find.bySemanticsLabel('Film Harbour Lights'));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      await tester.tap(smallPhoto('subtitles-1'));
      await tester.pump();
      expect(host.controller.selectedId, 'subtitles-1');
      expect(host.selections, ['subtitles-1']);
      handle.dispose();
    });

    testWidgets('the tab preview of a film-only session is the film icon', (tester) async {
      await PanelHost(photos: [fakeFilm('subtitles-1')]).pump(tester);
      final tile = find.descendant(of: tabFinder, matching: find.byType(SourceTile));
      expect(tester.widget<SourceTile>(tile).mini, isTrue);
      expect(find.descendant(of: tile, matching: find.byIcon(Icons.movie_outlined)), findsOneWidget);
    });
  });
}
