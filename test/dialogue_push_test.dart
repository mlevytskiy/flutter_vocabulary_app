import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/dialogues/dialogue_push.dart';
import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_picture_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';

/// get-words-from-subtitles-improvment T24: an import's rows and dialogues,
/// and later scene pictures, reach the shared link on their own (ADR-0005).
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

  late Directory dir;
  late CollectionStore store;
  late StoryRunStore runStore;
  late StoryPictureStore pictures;
  late List<http.Request> requests;
  late int Function(http.Request) answer;
  late WordCollection collection;
  ProviderContainer? container;

  ProviderContainer start() {
    final c = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runStore),
      storyPictureStoreProvider.overrideWithValue(pictures),
      dialoguePushServiceProvider.overrideWithValue(DialoguePushService(
        client: MockClient((request) async {
          requests.add(request);
          final status = answer(request);
          return http.Response(jsonEncode(status == 200 ? {'ok': true} : {'code': 'gone'}), status);
        }),
      )),
      dialoguePushPauseProvider.overrideWithValue(const Duration(milliseconds: 20)),
    ]);
    container = c;
    return c;
  }

  WordPair pair(String id, String word) => WordPair(word: word, translation: 'т-$word', rowId: id);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('dialogue_push_test');
    store = await CollectionStore.open(directory: dir.path);
    runStore = await StoryRunStore.open(directory: dir.path);
    pictures = StoryPictureStore(directory: dir.path, compress: (b, q) async => b);
    requests = [];
    answer = (_) => 200;
    collection = WordCollection.create()
      ..words = [pair('r0', 'tide'), pair('r1', 'attic'), pair('r2', 'dusty')]
      ..publishedId = 'pub'
      ..editToken = 'tok'
      ..dialogues = [
        FilmDialogue()
          ..id = 'd1'
          ..lines = ['The attic.']
          ..wordRowIds = ['r1']
          ..importId = 'imp-1'
          ..importRowIds = ['r1', 'r2']
          ..pushState = PushState.pending,
      ]
      ..lastLocalModifiedAt = DateTime.now();
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> save() async {
    await store.put(collection);
    await store.setCurrentCollectionId(collection.collectionId);
  }

  Future<WordCollection> saved() async => (await store.byId(collection.collectionId))!;

  Future<void> runOnce(ProviderContainer c) => c.read(dialoguePushProvider.notifier).run();

  test('a pending import goes to the append route once, then is delivered', () async {
    await save();
    final c = start();
    await c.read(dialoguePushProvider.notifier).startup;
    await runOnce(c);

    expect(requests, hasLength(1));
    final r = requests.single;
    expect(r.url.path, '/sessions/pub/dialogues');
    expect(r.headers['x-edit-token'], 'tok');
    expect(r.headers['x-app-secret'], isNotEmpty);
    expect(jsonDecode(r.body), {
      'importId': 'imp-1',
      'entries': [
        {'word': 'attic', 'translation': 'т-attic'},
        {'word': 'dusty', 'translation': 'т-dusty'},
      ],
      'dialogues': [
        {'id': 'd1', 'lines': ['The attic.'], 'entries': [0]},
      ],
    });
    expect((await saved()).dialogues.single.pushState, PushState.delivered);
  });

  test('a failed delivery is sent again after a restart, with the same import id', () async {
    await save();
    answer = (_) => 503;
    final first = start();
    await first.read(dialoguePushProvider.notifier).startup;
    expect((await saved()).dialogues.single.pushState, PushState.pending);
    first.dispose();
    container = null;

    answer = (_) => 200;
    final restarted = start();
    await restarted.read(dialoguePushProvider.notifier).startup;

    expect(requests.length, greaterThanOrEqualTo(2));
    expect({for (final r in requests) jsonDecode(r.body)['importId']}, {'imp-1'});
    expect((await saved()).dialogues.single.pushState, PushState.delivered);
  });

  test('a dialogue whose words were all deleted is hidden: the rows go, then it is removed', () async {
    collection
      ..words = [pair('r0', 'tide'), pair('r2', 'dusty')]
      ..dialogues.single.wordRowIds = []
      ..dialogues.single.hidden = true;
    await save();
    final c = start();
    await c.read(dialoguePushProvider.notifier).startup;

    expect(jsonDecode(requests.single.body), {
      'importId': 'imp-1',
      'entries': [
        {'word': 'dusty', 'translation': 'т-dusty'},
      ],
      'dialogues': [],
    });
    expect((await saved()).dialogues, isEmpty);
  });

  test('a collected scene picture is uploaded to its dialogue', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    collection.dialogues.single
      ..pushState = PushState.delivered
      ..scenePictureRunId = 'run-1'
      ..picturePushState = PushState.pending;
    await save();
    await runStore.put(StoryRun()
      ..runId = 'run-1'
      ..collectionId = collection.collectionId
      ..groupId = 'dialogue-d1'
      ..groupName = 'The attic.'
      ..startedAt = DateTime(2026, 10, 13)
      ..kind = StoryRunKind.scene
      ..outcome = 'done'
      ..collected = true
      ..steps = [
        StoryStep()
          ..role = 'picture'
          ..attempt = 2
          ..outcome = 'done'
          ..picturePath = 'x',
      ]);
    await pictures.write('run-1', 2, bytes);

    final c = start();
    await c.read(dialoguePushProvider.notifier).startup;

    final r = requests.single;
    expect(r.url.path, '/sessions/pub/dialogues/d1/picture');
    expect(r.headers['content-type'], 'image/jpeg');
    expect(r.headers['x-edit-token'], 'tok');
    expect(r.bodyBytes, bytes);
    expect((await saved()).dialogues.single.picturePushState, PushState.delivered);
  });

  test('a gone link stops the retries and drops the delivery', () async {
    await save();
    answer = (_) => 404;
    final c = start();
    await c.read(dialoguePushProvider.notifier).startup;
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(requests, hasLength(1));
    expect((await saved()).dialogues.single.pushState, PushState.delivered);
  });

  test('a session without a link sends nothing', () async {
    collection
      ..publishedId = null
      ..editToken = null;
    await save();
    final c = start();
    await c.read(dialoguePushProvider.notifier).startup;
    expect(requests, isEmpty);
  });
}
