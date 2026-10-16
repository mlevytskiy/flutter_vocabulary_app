import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photos_with_words.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// side-bar-for-main-screen T2: the current session's photos with words, in
/// the order they were added, each with its linked rows (spec AC-02, AC-03,
/// AC-15, AC-16).
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
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('photos_with_words_test');
    store = await CollectionStore.open(directory: dir.path);
    container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  SessionSource photo(String id) => SessionSource()
    ..id = id
    ..fileName = '$id.jpg'
    ..takenAt = DateTime(2026, 10, 13);

  Future<WordInputNotifier> seeded(
      {List<SessionSource> sources = const [], List<WordPair> pairs = const []}) async {
    await container.read(wordInputNotifierProvider.future);
    final notifier = container.read(wordInputNotifierProvider.notifier);
    for (final s in sources) {
      notifier.addSource(s);
    }
    notifier.setPairs(pairs);
    return notifier;
  }

  /// Each photo as `id:row,row` so the lists compare by value.
  List<String> listed() => [
        for (final p in container.read(photosWithWordsProvider))
          '${p.source.id}:${p.rows.join(',')}',
      ];

  test('before the session loads, the list is empty', () {
    final loading = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) => Completer<CollectionStore>().future),
    ]);
    addTearDown(loading.dispose);
    expect(loading.read(photosWithWordsProvider), isEmpty);
  });

  test('a typed session has no photos with words', () async {
    await seeded(pairs: [WordPair(word: 'cat'), WordPair(word: 'dog')]);
    expect(listed(), isEmpty);
  });

  test('a Quizlet-only session has no photos with words', () async {
    final notifier = await seeded();
    final setId = notifier.upsertSetSource('123', 'Set', 'https://quizlet.com/123/x/');
    notifier.setPairs([WordPair(word: 'cat', sourceId: setId)]);
    expect(listed(), isEmpty);
  });

  List<String> sourcesListed() => [
        for (final p in container.read(sourcesWithWordsProvider))
          '${p.source.id}:${p.rows.join(',')}',
      ];

  test('a Quizlet-only session lists its set among the sources (AC-21)', () async {
    final notifier = await seeded();
    final setId = notifier.upsertSetSource('123', 'Set', 'https://quizlet.com/123/x/');
    notifier.setPairs([WordPair(word: 'cat', sourceId: setId), WordPair(word: 'typed')]);
    expect(sourcesListed(), ['quizlet-123:0']);
  });

  test('photos and sets are mixed, oldest first by takenAt (AC-21)', () async {
    SessionSource at(String id, int minute, {bool set = false}) => SessionSource()
      ..id = id
      ..kind = set ? SourceKind.set : SourceKind.photo
      ..takenAt = DateTime(2026, 10, 13, 9, minute);
    await seeded(
      // Listed out of time order on purpose.
      sources: [at('p2', 3), at('s1', 2, set: true), at('p1', 1), at('s0', 9, set: true)],
      pairs: [
        WordPair(word: 'a', sourceId: 'p1'),
        WordPair(word: 'b', sourceId: 's1'),
        WordPair(word: 'c', sourceId: 'p2'),
        WordPair(word: '  ', sourceId: 's0'), // cleared: s0 has no words
      ],
    );
    expect(sourcesListed(), ['p1:0', 's1:1', 'p2:2']);
    expect(listed(), ['p1:0', 'p2:2'], reason: 'photos only, for full-open');
  });

  test('a mixed session lists only linked photos, in the order added, with their rows', () async {
    await seeded(
      sources: [photo('p1'), photo('p2'), photo('p3')],
      pairs: [
        WordPair(word: 'typed'),
        WordPair(word: 'b', sourceId: 'p2'),
        WordPair(word: 'a', sourceId: 'p1'),
        WordPair(word: 'b2', sourceId: 'p2'),
        WordPair(word: 'ghost', sourceId: 'gone'), // a source the session does not list
      ],
    );
    expect(listed(), ['p1:2', 'p2:1,3']);
  });

  test('a photo whose last row is deleted disappears at once', () async {
    final notifier = await seeded(
      sources: [photo('p1'), photo('p2')],
      pairs: [WordPair(word: 'a', sourceId: 'p1'), WordPair(word: 'b', sourceId: 'p2')],
    );
    expect(listed(), ['p1:0', 'p2:1']);
    notifier.removeAt(0);
    expect(listed(), ['p2:0']);
  });

  test('a row whose word is cleared does not count as linked', () async {
    final notifier = await seeded(
      sources: [photo('p1')],
      pairs: [WordPair(word: 'a', sourceId: 'p1')],
    );
    notifier.updateAt(0, word: '  ');
    expect(listed(), isEmpty);
  });

  test('a new photo with words appears without a manual refresh', () async {
    final notifier = await seeded(
      sources: [photo('p1')],
      pairs: [WordPair(word: 'a', sourceId: 'p1')],
    );
    var builds = 0;
    container.listen(photosWithWordsProvider, (_, __) => builds++);
    notifier.addSource(photo('p2'));
    notifier.addAll([WordPair(word: 'b', sourceId: 'p2')]);
    expect(listed(), ['p1:0', 'p2:1']);
    expect(builds, greaterThan(0));
  });
}
