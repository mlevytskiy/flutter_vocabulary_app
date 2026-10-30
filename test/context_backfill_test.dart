import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/definition_result.dart';
import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/dictionary_service.dart';
import 'package:flutter_vocabulary_app/core/words/context_backfill.dart';
import 'package:flutter_vocabulary_app/core/words/word_origin_rules.dart';

import 'seed_collections.dart';

/// word-context T10 (AC-12, ADR-0004): the launch backfill of empty contexts.
class FakeDictionary extends DictionaryService {
  final List<String> asked = [];
  DefinitionResult Function(String word) answer =
      (w) => DefinitionResult.found([
            'definition: something else\nexample: Another $w here.',
            'definition: the $w meaning\nexample: The $w in use.',
          ]);

  @override
  Future<DefinitionResult> define(String word) async {
    asked.add(word);
    return answer(word);
  }
}

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
  late FakeDictionary dictionary;
  late DateTime clock;
  late List<Duration> sleeps;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('context_backfill_test');
    store = await CollectionStore.open(directory: dir.path);
    dictionary = FakeDictionary();
    clock = DateTime(2026, 10, 30, 9);
    sleeps = [];
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ContextBackfill backfill() => ContextBackfill(
        store: () async => store,
        dictionary: dictionary,
        now: () => clock,
        sleep: (d) async {
          sleeps.add(d);
          clock = clock.add(d);
        },
      );

  WordPair typed(String id, String word,
          {String definition = '', SourceType type = SourceType.manuallyEntered}) =>
      WordPair(word: word, translation: '$word-uk', definition: definition)
        ..rowId = id
        ..origin = (WordOrigin()..typeOfSource = type);

  WordPair from(String id, String word, SourceType type, String sourceId) =>
      typed(id, word, type: type)..sourceId = sourceId;

  Future<WordCollection> seed(List<WordPair> words,
      {List<SessionSource> sources = const [],
      List<FilmDialogue> dialogues = const []}) async {
    final c = WordCollection.create()
      ..words = words
      ..sources = [...sources]
      ..dialogues = [...dialogues]
      ..lastLocalModifiedAt = DateTime(2026, 10, 1);
    await seedCollection(store, c);
    return c;
  }

  Future<WordPair> stored(WordCollection c, String rowId) async =>
      (await store.byId(c.collectionId))!
          .words
          .firstWhere((w) => w.rowId == rowId);

  test('typed and set rows take the example of the sense matching their '
      'definition; a translation-only row is just marked tried', () async {
    final c = await seed([
      typed('a', 'cat', definition: 'definition: the cat meaning\nexample: x'),
      typed('b', 'dog',
          definition: 'something nobody has', type: SourceType.set),
      typed('c', 'owl'),
    ]);

    await backfill().run();

    final a = await stored(c, 'a');
    expect(a.context, 'The cat in use.');
    expect(a.contextKind, ContextKind.source);
    expect(a.contextTried, isTrue);
    final b = await stored(c, 'b');
    expect(b.context, 'Another dog here.', reason: 'no sense matches: first');
    expect(b.contextTried, isTrue);
    final owl = await stored(c, 'c');
    expect(owl.context, '');
    expect(owl.contextKind, ContextKind.none);
    expect(owl.contextTried, isTrue);
    expect(dictionary.asked, ['cat', 'dog']);
    expect((await store.byId(c.collectionId))!.lastLocalModifiedAt,
        DateTime(2026, 10, 1), reason: 'the edit time stays');
  });

  test('a dictionary that finds nothing marks the row tried; one that is '
      'unavailable leaves it for the next launch and is not asked again',
      () async {
    final c = await seed([
      typed('a', 'zzq', definition: 'made up'),
    ]);
    dictionary.answer = (_) => const DefinitionResult.notFound([]);
    await backfill().run();
    expect((await stored(c, 'a')).contextTried, isTrue);

    final d = await seed([
      typed('x', 'one', definition: 'd'),
      typed('y', 'two', definition: 'd'),
    ]);
    dictionary
      ..asked.clear()
      ..answer = (_) => const DefinitionResult.unavailable();
    await backfill().run();
    expect(dictionary.asked, hasLength(1));
    expect((await stored(d, 'x')).contextTried, isFalse);
    expect((await stored(d, 'y')).contextTried, isFalse);
  });

  test('a film row takes the first stored dialogue line that has the word '
      'as a whole word', () async {
    final c = await seed([
      from('f1', 'cat', SourceType.movie, 's'),
      from('f2', 'run', SourceType.movie, 's'),
      from('f3', 'zebra', SourceType.movie, 's'),
    ], dialogues: [
      FilmDialogue()
        ..id = 'd1'
        ..lines = ['A category of things.', 'The cat is back!', 'We ran.'],
      FilmDialogue()
        ..id = 'd2'
        ..lines = ['He runs home, kid.'],
    ]);

    await backfill().run();

    expect((await stored(c, 'f1')).context, 'The cat is back!');
    expect((await stored(c, 'f1')).contextKind, ContextKind.source);
    expect((await stored(c, 'f2')).context, 'He runs home, kid.');
    final zebra = await stored(c, 'f3');
    expect(zebra.context, '');
    expect(zebra.contextTried, isTrue);
    expect(dictionary.asked, isEmpty);
  });

  test("a photo row takes the sentence of its photo's stored full text; a "
      'photo without one is never analysed again, only marked tried', () async {
    final c = await seed([
      from('p1', 'harbour', SourceType.image, 'ph1'),
      from('p2', 'river', SourceType.image, 'ph2'),
    ], sources: [
      SessionSource()
        ..id = 'ph1'
        ..fullText = 'Welcome to town. Boats rest in the\nold harbour at '
            'night! Tickets inside.',
      SessionSource()..id = 'ph2',
    ]);

    await backfill().run();

    final p1 = await stored(c, 'p1');
    expect(p1.context, 'Boats rest in the old harbour at night!');
    expect(p1.contextKind, ContextKind.source);
    final p2 = await stored(c, 'p2');
    expect(p2.context, '');
    expect(p2.contextTried, isTrue);
  });

  test('tried rows and rows with a context are skipped; a changed word is '
      'tried again', () async {
    final c = await seed([
      typed('a', 'cat', definition: 'd')..contextTried = true,
      typed('b', 'dog', definition: 'd')
        ..context = 'Mine.'
        ..contextKind = ContextKind.ai,
    ]);

    await backfill().run();
    expect(dictionary.asked, isEmpty);
    expect((await stored(c, 'b')).context, 'Mine.');

    final copy = (await store.byId(c.collectionId))!;
    copy.words[0] = withChangedWord(copy.words[0]..word = 'cow');
    await store.put(copy);

    await backfill().run();
    expect(dictionary.asked, ['cow']);
    expect((await stored(c, 'a')).context, 'Another cow here.');
  });

  test('at most 20 words a minute, each minute written before the wait',
      () async {
    final c = await seed([
      for (var i = 0; i < 45; i++) typed('r$i', 'w$i', definition: 'd'),
    ]);
    final times = <DateTime>[];
    final storedAtWait = <int>[];
    final b = ContextBackfill(
      store: () async => store,
      dictionary: dictionary,
      now: () => clock,
      sleep: (d) async {
        sleeps.add(d);
        final s = await store.byId(c.collectionId);
        storedAtWait.add(s!.words.where((w) => w.contextTried).length);
        clock = clock.add(d);
      },
    );
    dictionary.answer = (w) {
      times.add(clock);
      return DefinitionResult.found(['definition: d\nexample: $w ok.']);
    };

    final written = <int>[];
    await b.start(onWritten: (_, fills) => written.add(fills.length));

    expect(dictionary.asked, hasLength(45));
    expect(sleeps, [const Duration(minutes: 1), const Duration(minutes: 1)]);
    for (var i = 0; i < times.length; i++) {
      expect(times[i], DateTime(2026, 10, 30, 9, i ~/ 20));
    }
    expect(storedAtWait, [20, 40]);
    expect(written, [20, 20, 5]);
    final s = await store.byId(c.collectionId);
    expect(s!.words.every((w) => w.contextTried && w.context.isNotEmpty),
        isTrue);
  });

  test('start runs once', () async {
    await seed([typed('a', 'cat', definition: 'd')]);
    final b = backfill();
    await Future.wait([b.start(), b.start()]);
    await b.start();
    expect(dictionary.asked, ['cat']);
  });

  test('a cancelled backfill reads and writes nothing more', () async {
    final c = await seed([typed('a', 'cat', definition: 'd')]);
    final b = backfill()..cancel();
    await b.start();
    expect(dictionary.asked, isEmpty);
    expect((await stored(c, 'a')).contextTried, isFalse);
  });

  test('applyContextFills leaves a row changed since it was looked at', () {
    final rows = [typed('a', 'cat', definition: 'd')];
    final changed = applyContextFills(rows, [
      (rowId: 'a', word: 'dog', definition: 'd', context: 'The dog.'),
    ]);
    expect(changed, isFalse);
    expect(rows.single.contextTried, isFalse);
  });
}
