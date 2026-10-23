// collection-naming (owner, 2026-10-18): "Vocabulary N" for a collection
// nobody named, the AI's name from 5 words on, a typed name kept for good.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/models/name_kind.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_naming_service.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/collection_title.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';

import 'seed_collections.dart';

/// Answers [answer] (null: no name to be had) and counts the asks.
class FakeNaming extends CollectionNamingService {
  FakeNaming([this.answer = 'Kitchen Tools']);
  String? answer;
  final asked = <List<String>>[];
  Completer<void>? hold;

  @override
  Future<String?> nameFor(List<WordPair> words) async {
    asked.add([
      for (final w in words)
        if (w.word.trim().isNotEmpty) w.word
    ]);
    await hold?.future;
    return answer;
  }

  /// The launch upgrade's asks, and whether it answers (null: it fails).
  final autofills = <List<
      ({String id, List<WordPair> words, bool name, bool description})>>[];
  bool autofillAnswers = true;

  @override
  Future<Map<String, ({String? name, String? description})>?> autofill(
      List<({String id, List<WordPair> words, bool name, bool description})>
          items) async {
    autofills.add(items);
    if (!autofillAnswers) return null;
    return {
      for (final i in items)
        i.id: (
          name: i.name ? 'Name ${i.words.first.word}' : null,
          description: i.description ? 'About ${i.words.first.word}.' : null,
        ),
    };
  }

  String? description = 'Words for cooking at home.';
  final described = <List<String>>[];

  @override
  Future<String?> descriptionFor(List<WordPair> words) async {
    described.add([
      for (final w in words)
        if (w.word.trim().isNotEmpty) w.word
    ]);
    await hold?.future;
    return description;
  }
}

WordPair w(String s) => WordPair(word: s, translation: '$s-uk');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the pure rules', () {
    test('nextVocabularyName takes the first free of Vocabulary, 1, 2, …', () {
      expect(nextVocabularyName([]), 'Vocabulary');
      expect(nextVocabularyName(['Trip', null]), 'Vocabulary');
      expect(nextVocabularyName(['Vocabulary']), 'Vocabulary 1');
      expect(
          nextVocabularyName(['Vocabulary', 'Vocabulary 1']), 'Vocabulary 2');
      expect(nextVocabularyName(['Vocabulary 1']), 'Vocabulary');
      expect(
          nextVocabularyName(['Vocabulary', 'Vocabulary 2']), 'Vocabulary 1');
      expect(
          nextVocabularyName(['Vocabulary', 'Vocabulary 01', 'vocabulary 1']),
          'Vocabulary 1');
    });

    test('isVocabularyName and isDateName', () {
      expect(isVocabularyName('Vocabulary'), isTrue);
      expect(isVocabularyName('Vocabulary 12'), isTrue);
      expect(isVocabularyName('Vocabulary words'), isFalse);
      expect(isDateName(defaultCollectionName(DateTime(2026, 1, 2, 3, 4))),
          isTrue);
      expect(isDateName('Kitchen'), isFalse);
    });

    test('cleanAutoName makes the AI\'s answer a name the store takes', () {
      expect(cleanAutoName('  "Kitchen\n Tools."  '), 'Kitchen Tools');
      expect(cleanAutoName(''), isNull);
      expect(cleanAutoName('""'), isNull);
      final long = cleanAutoName('word ' * 20)!;
      expect(long.runes.length, lessThanOrEqualTo(maxCollectionNameLength));
      expect(long.endsWith(' '), isFalse);
    });
  });

  group('CollectionNamingService', () {
    test('posts the words and the model, reads the name', () async {
      late Map<String, dynamic> sent;
      final service =
          CollectionNamingService(client: MockClient((request) async {
        expect(request.url.path, '/collections/name');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'name': 'Kitchen Tools.'}), 200);
      }));
      final name = await service.nameFor([w('fork'), WordPair(), w('pan')]);
      expect(name, 'Kitchen Tools');
      expect(sent['model'], 'claude-sonnet-5-5');
      expect(sent['words'], [
        {'word': 'fork', 'translation': 'fork-uk'},
        {'word': 'pan', 'translation': 'pan-uk'},
      ]);
    });

    test('autofill: one post for many, answers by id, only what was wanted',
        () async {
      late Map<String, dynamic> sent;
      final service =
          CollectionNamingService(client: MockClient((request) async {
        expect(request.url.path, '/collections/autofill');
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
            jsonEncode({
              'collections': [
                {'id': 'a', 'name': '"Kitchen."', 'description': 'unwanted'},
                {'id': 'b', 'description': 'About b.'},
                {'id': 'zz', 'name': 'not asked'},
              ],
            }),
            200);
      }));
      final answers = await service.autofill([
        (id: 'a', words: [w('fork')], name: true, description: false),
        (
          id: 'b',
          words: [for (var i = 0; i < 40; i++) w('w$i')],
          name: false,
          description: true
        ),
      ]);
      expect(answers, {
        'a': (name: 'Kitchen', description: null),
        'b': (name: null, description: 'About b.'),
      });
      final collections = sent['collections'] as List;
      expect(collections[0]['want'], ['name']);
      expect(collections[1]['want'], ['description']);
      expect((collections[1]['words'] as List).length, 30);
      expect(sent['model'], 'claude-sonnet-5-5');

      final failing = CollectionNamingService(
          client: MockClient((_) async => http.Response('{}', 502)));
      expect(
          await failing.autofill([
            (id: 'a', words: [w('x')], name: true, description: false)
          ]),
          isNull);
    });

    test('null on a refusal or a broken answer, never a throw', () async {
      for (final response in [
        http.Response('{"code":"naming_failed"}', 502),
        http.Response('not json', 200),
        http.Response('{"name": 3}', 200),
      ]) {
        final service =
            CollectionNamingService(client: MockClient((_) async => response));
        expect(await service.nameFor([w('a')]), isNull);
      }
      final offline = CollectionNamingService(
          client: MockClient((_) async => throw const SocketException('off')));
      expect(await offline.nameFor([w('a')]), isNull);
    });
  });

  group('with a store', () {
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('collection_naming_test');
      store = await CollectionStore.open(directory: dir.path);
    });

    tearDown(() async {
      await store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('create: Vocabulary, Vocabulary 1, …; a typed name is by the user',
        () async {
      final a = await store.create();
      final b = await store.create();
      final typed = await store.create(name: 'Trip');
      final blank = await store.create(name: '');
      expect([a.name, b.name, typed.name, blank.name],
          ['Vocabulary', 'Vocabulary 1', 'Trip', 'Vocabulary 2']);
      expect((await store.byId(a.collectionId))!.nameKind, NameKind.undefined);
      expect((await store.byId(typed.collectionId))!.nameKind, NameKind.byUser);
    });

    test('setAutoName goes in only while undefined; put keeps the kind',
        () async {
      final c = await store.create();
      final stored = await store.setAutoName(c.collectionId, 'Kitchen Tools');
      expect(stored?.name, 'Kitchen Tools');
      expect(stored?.nameKind, NameKind.auto);
      expect(stored?.updatedAt, c.updatedAt);
      // A second AI answer does not replace the first.
      expect(await store.setAutoName(c.collectionId, 'Other'), isNull);
      // A whole-copy save from a stale caller keeps name and kind.
      await store.put(c..words = [w('fork')]);
      final after = (await store.byId(c.collectionId))!;
      expect((after.name, after.nameKind), ('Kitchen Tools', NameKind.auto));
    });

    test('rename and the details sheet make the name the user\'s', () async {
      final a = await store.create();
      final b = await store.create();
      await store.rename(a.collectionId, 'Mine');
      await store.setDetails(b.collectionId, name: 'Also mine');
      expect((await store.byId(a.collectionId))!.nameKind, NameKind.byUser);
      expect((await store.byId(b.collectionId))!.nameKind, NameKind.byUser);
      expect(await store.setAutoName(a.collectionId, 'AI'), isNull);
      // The sheet saved with the name unchanged leaves the kind alone.
      final c = await store.create();
      await store.setDetails(c.collectionId, name: c.name, description: 'd');
      expect((await store.byId(c.collectionId))!.nameKind, NameKind.undefined);
    });

    test('setAutoDescription goes in only while nobody wrote one', () async {
      final c = await store.create();
      expect((await store.byId(c.collectionId))!.descriptionKind,
          NameKind.undefined);
      final stored =
          await store.setAutoDescription(c.collectionId, 'About food.');
      expect((stored?.description, stored?.descriptionKind),
          ('About food.', NameKind.auto));
      expect(stored?.updatedAt, c.updatedAt);
      expect(await store.setAutoDescription(c.collectionId, 'Other.'), isNull);
      await store.put(c);
      final after = (await store.byId(c.collectionId))!;
      expect((after.description, after.descriptionKind),
          ('About food.', NameKind.auto));

      // Written by the learner, also when emptied: AI never writes it.
      final typed = await store.create(description: 'Mine');
      expect((await store.byId(typed.collectionId))!.descriptionKind,
          NameKind.byUser);
      final emptied = await store.create();
      await store.setAutoDescription(emptied.collectionId, 'AI text.');
      await store.setDetails(emptied.collectionId, description: '');
      final e = (await store.byId(emptied.collectionId))!;
      expect((e.description, e.descriptionKind), (null, NameKind.byUser));
      expect(await store.setAutoDescription(emptied.collectionId, 'Again.'),
          isNull);
    });

    test(
        'pendingAutofill: 5 words for a name, 20 for a description, '
        'never the learner\'s, never in the bin', () async {
      WordCollection c(int words,
              {NameKind name = NameKind.undefined,
              String? text,
              DateTime? binned}) =>
          WordCollection.create()
            ..name = 'Vocabulary'
            ..nameKind = name
            ..binnedAt = binned
            ..words = [for (var i = 0; i < words; i++) w('w$i')];
      final four = c(4);
      final five = c(5);
      final twenty = c(20);
      final typedTwenty = c(20, name: NameKind.byUser);
      final binned = c(25, binned: DateTime(2026, 10, 1));
      for (final x in [four, five, twenty, typedTwenty, binned]) {
        await seedCollection(store, x);
      }
      final pending = {
        for (final p in await store.pendingAutofill())
          p.collection.collectionId: (p.name, p.description),
      };
      expect(pending, {
        five.collectionId: (true, false),
        twenty.collectionId: (true, true),
        typedTwenty.collectionId: (false, true),
      });
    });

    test('opening sorts the names from before', () async {
      final date = defaultCollectionName(DateTime(2026, 3, 1, 9, 5));
      WordCollection old(String name, int words) => WordCollection.create()
        ..name = name
        ..words = [for (var i = 0; i < words; i++) w('w$i')];
      final small = old(date, 2);
      final big = old(date, 5);
      final typed = old('Travel', 1);
      final vocab = old('Vocabulary', 0);
      final described = old('Vocabulary', 0)..description = 'Old notes';
      for (final c in [small, big, typed, vocab, described]) {
        await seedCollection(store, c);
      }
      // put() takes no description from a caller: write it as stored.
      final isar = Isar.getInstance('vocab')!;
      await isar.writeTxn(() async {
        final d = (await isar.wordCollections
            .filter()
            .collectionIdEqualTo(described.collectionId)
            .findFirst())!;
        await isar.wordCollections.put(d..description = 'Old notes');
      });
      await store.close();
      store = await CollectionStore.open(directory: dir.path);

      Future<(String?, NameKind)> of(WordCollection c) async {
        final s = (await store.byId(c.collectionId))!;
        return (s.name, s.nameKind);
      }

      expect(await of(small), ('Vocabulary 1', NameKind.undefined));
      expect(await of(big), (date, NameKind.undefined));
      expect(await of(typed), ('Travel', NameKind.byUser));
      expect(await of(vocab), ('Vocabulary', NameKind.undefined));
      expect((await store.byId(described.collectionId))!.descriptionKind,
          NameKind.byUser);
      expect((await store.byId(vocab.collectionId))!.descriptionKind,
          NameKind.undefined);
    });

    group('the main screen\'s collection', () {
      late ProviderContainer container;
      late FakeNaming naming;

      setUp(() {
        naming = FakeNaming();
        container = ProviderContainer(overrides: [
          collectionStoreProvider.overrideWith((ref) async => store),
          collectionNamingServiceProvider.overrideWithValue(naming),
        ]);
      });
      tearDown(() => container.dispose());

      WordsNotifier notifier() =>
          container.read(wordsProvider.notifier);
      WordCollection shown() =>
          container.read(wordsProvider).value!;

      Future<WordCollection> open() async {
        await container.read(wordsProvider.future);
        return shown();
      }

      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 100));

      test('launch: every old collection asked about in one request', () async {
        final date = defaultCollectionName(DateTime(2026, 3, 1, 9, 5));
        WordCollection old(String name, int words, String first) =>
            WordCollection.create()
              ..name = name
              ..words = [
                for (var i = 0; i < words; i++) w(i == 0 ? first : '$first$i')
              ];
        final big = old(date, 6, 'fork');
        final long = old('Travel', 25, 'plane');
        final small = old(date, 3, 'cat');
        for (final x in [small, long, big]) {
          await seedCollection(store, x);
        }
        await store.close();
        store = await CollectionStore.open(directory: dir.path);
        await store.setCurrentCollectionId(big.collectionId);

        final shownCollection = await open();
        await settle();

        expect(naming.autofills, hasLength(1));
        expect({
          for (final i in naming.autofills.single) i.id: (i.name, i.description)
        }, {
          big.collectionId: (true, false),
          long.collectionId: (false, true),
        });
        // The current one was in the batch: no single ask on top.
        expect(naming.asked, isEmpty);
        final b = (await store.byId(big.collectionId))!;
        expect((b.name, b.nameKind), ('Name fork', NameKind.auto));
        final l = (await store.byId(long.collectionId))!;
        expect((l.name, l.nameKind), ('Travel', NameKind.byUser));
        expect((l.description, l.descriptionKind),
            ('About plane.', NameKind.auto));
        expect((await store.byId(small.collectionId))!.name, 'Vocabulary');
        expect(shownCollection.collectionId, big.collectionId);
        expect(shown().name, 'Name fork');
      });

      test(
          'launch: a failed upgrade leaves them; the current one is asked '
          'alone after it', () async {
        naming.autofillAnswers = false;
        final big = WordCollection.create()
          ..name = 'Vocabulary 4'
          ..words = [for (var i = 0; i < 5; i++) w('w$i')];
        await seedCollection(store, big);
        await store.setCurrentCollectionId(big.collectionId);
        await open();
        await settle();
        expect(naming.autofills, hasLength(1));
        expect(naming.asked, hasLength(1));
        expect((await store.byId(big.collectionId))!.name, 'Kitchen Tools');
      });

      test(
          'Replace all date names: small ones "Vocabulary N" at once, the '
          'rest named in one request, even a typed date', () async {
        await open();
        await settle();
        final date = defaultCollectionName(DateTime(2026, 10, 17, 17, 5));
        WordCollection c(int words, String first,
                {NameKind kind = NameKind.undefined, DateTime? binned}) =>
            WordCollection.create()
              ..name = date
              ..nameKind = kind
              ..binnedAt = binned
              ..words = [
                for (var i = 0; i < words; i++) w(i == 0 ? first : '$first$i')
              ];
        final small = c(2, 'cat');
        final big = c(7, 'fork', kind: NameKind.byUser);
        final long = c(22, 'plane');
        final binned = c(1, 'old', binned: DateTime(2026, 10, 1));
        final mine = WordCollection.create()
          ..name = 'Trip'
          ..nameKind = NameKind.byUser
          ..words = [for (var i = 0; i < 9; i++) w('t$i')];
        for (final x in [small, big, long, binned, mine]) {
          await seedCollection(store, x);
        }

        final result = await notifier().replaceDateNames();

        expect(result, (vocabulary: 2, ai: 2, kept: 0));
        expect(naming.autofills, hasLength(1));
        expect({
          for (final i in naming.autofills.single) i.id: (i.name, i.description)
        }, {
          big.collectionId: (true, false),
          long.collectionId: (true, true)
        });
        Future<(String?, NameKind)> of(WordCollection x) async {
          final s = (await store.byId(x.collectionId))!;
          return (s.name, s.nameKind);
        }

        expect((await of(small)).$1, startsWith('Vocabulary'));
        expect((await of(binned)).$1, startsWith('Vocabulary'));
        expect(await of(big), ('Name fork', NameKind.auto));
        expect(await of(long), ('Name plane', NameKind.auto));
        expect(
            (await store.byId(long.collectionId))!.description, 'About plane.');
        expect(await of(mine), ('Trip', NameKind.byUser));

        expect(await notifier().replaceDateNames(),
            (vocabulary: 0, ai: 0, kept: 0));
        expect(naming.autofills, hasLength(1));
      });

      test('Replace all date names without an answer keeps the big dates',
          () async {
        await open();
        await settle();
        naming.autofillAnswers = false;
        final date = defaultCollectionName(DateTime(2026, 10, 17, 17, 5));
        final big = WordCollection.create()
          ..name = date
          ..words = [for (var i = 0; i < 6; i++) w('b$i')];
        await seedCollection(store, big);
        expect(await notifier().replaceDateNames(),
            (vocabulary: 0, ai: 0, kept: 1));
        expect((await store.byId(big.collectionId))!.name, date);
      });

      test('launch with nothing pending sends no request', () async {
        await open();
        await settle();
        expect(naming.autofills, isEmpty);
      });

      test('four words: no ask; the fifth asks once and names it', () async {
        final c = await open();
        expect(c.name, 'Vocabulary');
        notifier().addAll([w('fork'), w('spoon'), w('knife'), w('pan')]);
        await settle();
        expect(naming.asked, isEmpty);

        notifier().addAll([w('kettle')]);
        notifier().addAll([w('bowl')]);
        await settle();
        expect(naming.asked, hasLength(1));
        expect(
            naming.asked.single, ['fork', 'spoon', 'knife', 'pan', 'kettle']);
        expect(
            (shown().name, shown().nameKind), ('Kitchen Tools', NameKind.auto));
        final stored = (await store.byId(c.collectionId))!;
        expect(
            (stored.name, stored.nameKind), ('Kitchen Tools', NameKind.auto));

        notifier().addAll([w('cup')]);
        await settle();
        expect(naming.asked, hasLength(1));
      });

      test('a name typed while the AI thinks wins', () async {
        naming.hold = Completer<void>();
        final c = await open();
        notifier().addAll([for (var i = 0; i < 5; i++) w('w$i')]);
        await settle();
        await notifier().saveDetails(name: 'Mine');
        naming.hold!.complete();
        await settle();
        final stored = (await store.byId(c.collectionId))!;
        expect((stored.name, stored.nameKind), ('Mine', NameKind.byUser));
        expect(shown().name, 'Mine');
      });

      test('no answer keeps "Vocabulary" and is not asked again at once',
          () async {
        naming.answer = null;
        final c = await open();
        notifier().addAll([for (var i = 0; i < 5; i++) w('w$i')]);
        await settle();
        notifier().addAll([w('x')]);
        await settle();
        expect(naming.asked, hasLength(1));
        expect((await store.byId(c.collectionId))!.name, 'Vocabulary');
      });

      test('19 words: no description; the 20th asks once and fills it',
          () async {
        final c = await open();
        notifier().addAll([for (var i = 0; i < 19; i++) w('w$i')]);
        await settle();
        expect(naming.described, isEmpty);
        notifier().addAll([w('w19')]);
        notifier().addAll([w('w20')]);
        await settle();
        expect(naming.described, hasLength(1));
        expect(naming.described.single, hasLength(20));
        final stored = (await store.byId(c.collectionId))!;
        expect((stored.description, stored.descriptionKind),
            ('Words for cooking at home.', NameKind.auto));
        expect(shown().description, 'Words for cooking at home.');
      });

      test('a description the learner wrote, or emptied, is never sent',
          () async {
        await open();
        await notifier().saveDetails(description: 'Mine');
        await notifier().saveDetails(description: '');
        notifier().addAll([for (var i = 0; i < 21; i++) w('w$i')]);
        await settle();
        expect(naming.described, isEmpty);
      });

      test('a typed name is never sent', () async {
        await open();
        await notifier().saveDetails(name: 'Mine');
        notifier().addAll([for (var i = 0; i < 6; i++) w('w$i')]);
        await settle();
        expect(naming.asked, isEmpty);
      });

      test('a collection opened with 5 words and no name gets one', () async {
        final big = WordCollection.create()
          ..name = 'Vocabulary 3'
          ..words = [for (var i = 0; i < 5; i++) w('w$i')];
        // Stored after the launch upgrade, so opening it asks alone.
        await open();
        await settle();
        await seedCollection(store, big);
        await notifier().open(big.collectionId);
        await settle();
        expect(naming.asked, hasLength(1));
        expect((await store.byId(big.collectionId))!.name, 'Kitchen Tools');
      });
    });
  });

  group('CollectionTitle', () {
    Widget title(String text, {bool animate = true, String id = 'c1'}) =>
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: CollectionTitle(
                      text: text, collectionId: id, animate: animate),
                ),
                const Icon(Icons.edit),
              ]),
            ),
          ),
        );

    Finder plain(String text) => find.byWidgetPredicate(
        (w) => w is Text && w.data == text && w.maxLines == 1);

    testWidgets('the AI\'s name is revealed letter by letter, then plain',
        (tester) async {
      await tester.pumpWidget(title('Vocabulary 2'));
      expect(plain('Vocabulary 2'), findsOneWidget);

      await tester.pumpWidget(title('Kitchen Tools'));
      await tester.pump(CollectionTitle.duration ~/ 2);
      // Mid-reveal: single letters, some still on their way, none blurred
      // (a blur layer blanked the title on an Android phone).
      expect(find.text('K'), findsOneWidget);
      expect(find.byType(Opacity), findsWidgets);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(plain('Kitchen Tools'), findsNothing);

      await tester.pumpAndSettle();
      expect(plain('Kitchen Tools'), findsOneWidget);
      expect(find.byType(Opacity), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'swirl float: the title is never empty during the reveal, and the '
        'letters float off the line (owner, 2026-10-19)', (tester) async {
      await tester.pumpWidget(title('Vocabulary 2'));
      await tester.pumpWidget(title('Kitchen Tools'));
      var floated = false;
      const steps = 30;
      for (var i = 1; i < steps; i++) {
        await tester.pump(CollectionTitle.duration ~/ steps);
        // The opacity of every letter on screen: more than one whole letter
        // is always showing.
        final shown = tester
            .widgetList<Opacity>(find.descendant(
                of: find.byType(CollectionTitle),
                matching: find.byType(Opacity)))
            .fold<double>(0, (sum, o) => sum + o.opacity);
        expect(shown, greaterThan(1.0), reason: 'step $i of $steps');
        floated = floated ||
            tester
                .widgetList<Transform>(find.descendant(
                    of: find.byType(CollectionTitle),
                    matching: find.byType(Transform)))
                .any((tr) => tr.transform.getTranslation().y.abs() > 4);
      }
      expect(floated, isTrue);
      await tester.pumpAndSettle();
      expect(plain('Kitchen Tools'), findsOneWidget);
    });

    testWidgets(
        'no reveal without animate, for another collection, or with '
        'animations off', (tester) async {
      await tester.pumpWidget(title('Vocabulary'));
      await tester.pumpWidget(title('Mine', animate: false));
      await tester.pump();
      expect(plain('Mine'), findsOneWidget);

      await tester.pumpWidget(title('Other', id: 'c2'));
      await tester.pump();
      expect(plain('Other'), findsOneWidget);

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: title('Calm'),
      ));
      await tester.pump();
      expect(plain('Calm'), findsOneWidget);
    });

    testWidgets(
        'a bar title style with no font size still places every letter '
        '(owner\'s phone, 2026-10-19: the title row drew nothing)',
        (tester) async {
      Widget bar(String text) => MaterialApp(
            theme: ThemeData(
              // As the app's themes: the title style carries no font size.
              appBarTheme: const AppBarTheme(
                  titleTextStyle: TextStyle(color: Colors.black)),
            ),
            home: Scaffold(
              appBar: AppBar(
                title: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: CollectionTitle(
                        text: text, collectionId: 'c1', animate: true),
                  ),
                  const Icon(Icons.edit),
                ]),
              ),
            ),
          );
      await tester.pumpWidget(bar('Vocabulary'));
      await tester.pumpWidget(bar('Pear Entries'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(CollectionTitle.duration ~/ 6);
        final letters = find.descendant(
            of: find.byType(CollectionTitle), matching: find.byType(Opacity));
        expect(letters, findsWidgets);
        for (final e in letters.evaluate()) {
          final at = (e.renderObject! as RenderBox).localToGlobal(Offset.zero);
          expect(at.dx.isFinite && at.dy.isFinite, isTrue, reason: '$at');
        }
      }
      await tester.pumpAndSettle();
      expect(plain('Pear Entries'), findsOneWidget);
    });

    testWidgets('a long name ends one line with an ellipsis', (tester) async {
      await tester.pumpWidget(title('Vocabulary'));
      await tester.pumpWidget(title('A very long name ' * 4));
      await tester.pump(CollectionTitle.duration ~/ 2);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      final t = tester.widget<Text>(plain('A very long name ' * 4));
      expect(t.overflow, TextOverflow.ellipsis);
    });
  });
}
