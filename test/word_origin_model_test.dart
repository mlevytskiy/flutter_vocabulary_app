import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart' show BinResult;
import 'package:flutter_vocabulary_app/core/services/collection_publish_service.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/new_user_trial.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';

/// word-context T2 (AC-01, AC-14, ADR-0001): the origin record, the context
/// fields and the photo's full text default for old data and survive every
/// copy path — copy, JSON, the store's put, the recycle bin, an edit through
/// the notifier and the new-user trial's put-aside — while publishing never
/// sends them. One Isar store for the file (docs/testing.md rule 4); the
/// trial test closes and reopens it, so it runs last.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory documents;
  late CollectionStore store;

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('word_origin_model_test');
    documents = Directory('${root.path}/docs')..createSync();
    store = await CollectionStore.open(directory: documents.path);
  });

  tearDownAll(() async {
    await store.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  WordOrigin movie() => WordOrigin()
    ..typeOfSource = SourceType.movie
    ..movieName = 'Friends'
    ..season = 2
    ..episode = 7
    ..time = '00:12:31'
    ..wasTranslationEditByUser = true
    ..wasDescriptionEditByUser = true;

  WordPair row(String rowId) => WordPair(
        word: 'reluctant',
        translation: 'неохочий',
        rowId: rowId,
        context: 'I was reluctant to go.',
        contextKind: ContextKind.source,
        contextTried: true,
      )..origin = movie();

  void expectCarried(WordPair w) {
    expect(w.origin.typeOfSource, SourceType.movie);
    expect(w.origin.movieName, 'Friends');
    expect(w.origin.season, 2);
    expect(w.origin.episode, 7);
    expect(w.origin.time, '00:12:31');
    expect(w.origin.wasTranslationEditByUser, isTrue);
    expect(w.origin.wasDescriptionEditByUser, isTrue);
    expect(w.context, 'I was reluctant to go.');
    expect(w.contextKind, ContextKind.source);
    expect(w.contextTried, isTrue);
  }

  void expectDefaults(WordPair w) {
    expect(w.origin.typeOfSource, SourceType.manuallyEntered);
    expect(w.origin.movieName, '');
    expect(w.origin.season, isNull);
    expect(w.origin.episode, isNull);
    expect(w.origin.time, '');
    expect(w.origin.wasTranslationEditByUser, isFalse);
    expect(w.origin.wasDescriptionEditByUser, isFalse);
    expect(w.context, '');
    expect(w.contextKind, ContextKind.none);
    expect(w.contextTried, isFalse);
  }

  Future<String> stored(List<WordPair> words, {String? fullText}) async {
    final c = await store.create(keep: true);
    c.words = words;
    c.sources = [
      SessionSource()
        ..id = 'p1'
        ..fileName = 'p1.jpg'
        ..fullText = fullText,
    ];
    await store.put(c);
    return c.collectionId;
  }

  test('a new row has the defaults; the enum names are pinned', () {
    expectDefaults(WordPair(word: 'cup'));
    expect(SourceType.values.map((e) => e.name),
        ['manuallyEntered', 'movie', 'image', 'set']);
    expect(ContextKind.values.map((e) => e.name), ['none', 'source', 'ai']);
  });

  test('copy carries the fields and does not share the origin', () {
    final a = row('r1');
    final b = a.copy();
    expectCarried(b);
    b.origin.movieName = 'Lost';
    expect(a.origin.movieName, 'Friends');
  });

  test('JSON round-trips the fields; old JSON reads the defaults', () {
    final json = jsonDecode(jsonEncode(row('r1').toJson())) as Map<String, dynamic>;
    expectCarried(WordPair.fromJson(json));
    expect(json['origin']['typeOfSource'], 'movie');
    expect(json['contextKind'], 'source');

    final old = Map.of(json)
      ..remove('origin')
      ..remove('context')
      ..remove('contextKind')
      ..remove('contextTried');
    expectDefaults(WordPair.fromJson(old));
    expect(WordOrigin.fromJson({'typeOfSource': 'gone'}).typeOfSource,
        SourceType.manuallyEntered);
  });

  test('a collection JSON copy carries the row fields and the full text', () {
    final c = WordCollection.create()
      ..words = [row('r1')]
      ..sources = [SessionSource()..id = 'p1'..fullText = 'EXIT\nNo smoking'];
    final back = WordCollection.fromJson(
        jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expectCarried(back.words.single);
    expect(back.sources.single.fullText, 'EXIT\nNo smoking');
  });

  test('SessionSource.fullText: copy, JSON, and null for old data', () {
    final s = SessionSource()..id = 'p1'..fullText = 'EXIT';
    expect(s.copy().fullText, 'EXIT');
    expect(SessionSource.fromJson(s.toJson()).fullText, 'EXIT');
    expect(SessionSource().toJson().containsKey('fullText'), isFalse);
    expect(SessionSource.fromJson({'id': 'p1'}).fullText, isNull);
  });

  test('the store put keeps them; a default row reads back the defaults',
      () async {
    final id = await stored([row('r1'), WordPair(word: 'cup', rowId: 'r2')],
        fullText: 'EXIT');
    final read = (await store.byId(id))!;
    expectCarried(read.words[0]);
    expectDefaults(read.words[1]);
    expect(read.sources.single.fullText, 'EXIT');

    // A later put of an edited copy keeps them too.
    read.words[0].translation = 'небажаючий';
    await store.put(read);
    expectCarried((await store.byId(id))!.words[0]);
  });

  test('binning then restoring a collection keeps them', () async {
    final id = await stored([row('r1')], fullText: 'EXIT');
    await stored([WordPair(word: 'cup')]);
    await store.setCurrentCollectionId('somewhere-else');

    expect((await store.bin(id)).result, BinResult.done);
    expect((await store.restore(id)).result, BinResult.done);
    final read = (await store.byId(id))!;
    expectCarried(read.words.single);
    expect(read.sources.single.fullText, 'EXIT');
  });

  test('an edit through the words notifier and a move keep them', () async {
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
    addTearDown(container.dispose);
    await container.read(wordsProvider.future);
    final notifier = container.read(wordsProvider.notifier);
    notifier.setPairs([WordPair(word: 'cup', rowId: 'r0'), row('r1')]);

    notifier.updateAt(1, translation: 'небажаючий', definition: 'unwilling');
    notifier.reorder(1, 0);
    final words = container.read(wordsProvider).value!.words;
    expect(words[0].translation, 'небажаючий');
    expectCarried(words[0]);
  });

  test('an import filling the blank row sets its origin and context (T8)', () async {
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
    addTearDown(container.dispose);
    await container.read(wordsProvider.future);
    final notifier = container.read(wordsProvider.notifier);
    notifier.setPairs([WordPair(word: '')]);

    final film = WordOrigin()
      ..typeOfSource = SourceType.movie
      ..movieName = 'Film'
      ..time = '00:01:02';
    notifier.updateAt(0, word: 'tide', origin: film, context: 'The tide.', contextKind: ContextKind.source);
    film.movieName = 'changed after';
    final r = container.read(wordsProvider).value!.words.single;
    expect(r.origin.typeOfSource, SourceType.movie);
    expect(r.origin.movieName, 'Film', reason: 'a copy is kept');
    expect(r.origin.time, '00:01:02');
    expect(r.context, 'The tide.');
    expect(r.contextKind, ContextKind.source);
  });

  test('the new-user trial puts them aside and brings them back', () async {
    final id = await stored([row('r1')], fullText: 'EXIT');
    await store.close();
    final trial = NewUserTrial(
      documents: () async => documents,
      support: () async => Directory('${root.path}/support')..createSync(),
      closeDatabase: () async {},
    );

    await trial.start();
    expect(documents.listSync(), isEmpty);
    await trial.restore();

    store = await CollectionStore.open(directory: documents.path);
    final read = (await store.byId(id))!;
    expectCarried(read.words.single);
    expect(read.sources.single.fullText, 'EXIT');
  });

  test('publishing never sends them', () async {
    final requests = <http.Request>[];
    final service = CollectionPublishService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'id': '35ffe55d-907d-4540-a5bb-5bda856dc6f5',
            'url': 'https://example.workers.dev/s/x',
            'expiresAt': '2026-10-21T07:32:30.434Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await service.publish(
      [row('r1')..sourceId = 'p1'],
      sources: [
        SessionSource()
          ..id = 'p1'
          ..fullText = 'EXIT',
      ],
    );

    final body = utf8.decode(requests.single.bodyBytes);
    for (final key in [
      'origin',
      'typeOfSource',
      'movieName',
      'context',
      'contextKind',
      'contextTried',
      'fullText',
      'EXIT',
      'I was reluctant',
    ]) {
      expect(body, isNot(contains(key)), reason: key);
    }
  });
}
