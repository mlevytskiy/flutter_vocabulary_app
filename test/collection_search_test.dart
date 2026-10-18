import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search.dart';

final now = DateTime(2026, 10, 16, 15, 30);

CollectionSummary s(
  String id, {
  String? name,
  String description = '',
  List<String> origin = const [],
  List<String> topic = const [],
  Set<String> srcOrigin = const {},
  Set<String> srcTopic = const {},
  String path = '',
  int index = 0,
  DateTime? created,
  DateTime? edited,
}) =>
    CollectionSummary(
      id: id,
      name: name ?? id,
      description: description,
      originTags: origin,
      topicTags: topic,
      sourceOriginKeys: srcOrigin,
      sourceTopicKeys: srcTopic,
      folderPath: path,
      treeIndex: index,
      created: created ?? DateTime(2026, 1, 1),
      edited: edited ?? DateTime(2026, 1, 1),
    );

List<String> ids(List<CollectionSummary> r) => [for (final c in r) c.id];

List<String> run(List<CollectionSummary> all, CollectionFilter f) =>
    ids(searchCollections(all, f, now: now));

void main() {
  group('query (AC-19)', () {
    final all = [
      s('a', name: 'Kitchen talk', description: 'From the cooking podcast'),
      s('b', name: 'Other', origin: ['Cookbook'], index: 1),
      s('c', name: 'Third', topic: ['COOKING'], index: 2),
      s('d', name: 'Nope', index: 3),
    ];
    test('matches name, description, origin and topic tags, ignoring case', () {
      expect(run(all, const CollectionFilter(query: 'COOK')), ['a', 'b', 'c']);
      expect(run(all, const CollectionFilter(query: 'kitchen')), ['a']);
    });
    test('substring, trimmed; empty query matches all', () {
      expect(run(all, const CollectionFilter(query: ' itch ')), ['a']);
      expect(run(all, const CollectionFilter()), ['a', 'b', 'c', 'd']);
    });
    test('isActive', () {
      expect(const CollectionFilter().isActive, isFalse);
      expect(const CollectionFilter(query: '  ').isActive, isFalse);
      expect(const CollectionFilter(query: 'x').isActive, isTrue);
      expect(const CollectionFilter(originTags: ['A']).isActive, isTrue);
      expect(
        const CollectionFilter(created: DateChoice.last7Days).isActive,
        isTrue,
      );
      expect(
        const CollectionFilter(sort: CollectionSort.nameAZ).isActive,
        isFalse,
      );
    });
  });

  group('tags (AC-20, AC-37)', () {
    final all = [
      s('both', origin: ['Series'], topic: ['Food', 'Home']),
      s('one', origin: ['Series'], index: 1),
      s('two', origin: ['Series', 'Film'], topic: ['food'], index: 2),
    ];
    test('all picked tags must match, ignoring case', () {
      expect(
        run(
          all,
          const CollectionFilter(originTags: ['series'], topicTags: ['FOOD']),
        ),
        ['both', 'two'],
      );
      expect(
        run(all, const CollectionFilter(originTags: ['Series', 'Film'])),
        ['two'],
      );
      expect(
        run(all, const CollectionFilter(topicTags: ['Food', 'Home'])),
        ['both'],
      );
    });
    test('a source tag does not count for the filter', () {
      final c = [
        s('x', srcTopic: {'food'})
      ];
      expect(run(c, const CollectionFilter(topicTags: ['Food'])), isEmpty);
    });
    test('query and tags and dates together', () {
      final c = [
        s(
          'hit',
          name: 'Dark S1',
          origin: ['Series'],
          created: DateTime(2026, 10, 1),
        ),
        s(
          'old',
          name: 'Dark S0',
          origin: ['Series'],
          created: DateTime(2026, 1, 1),
          index: 1,
        ),
        s(
          'notag',
          name: 'Dark S2',
          created: DateTime(2026, 10, 1),
          index: 2,
        ),
      ];
      expect(
        run(
          c,
          const CollectionFilter(
            query: 'dark',
            originTags: ['Series'],
            created: DateChoice.last30Days,
          ),
        ),
        ['hit'],
      );
    });
  });

  group('date ranges (AC-20b, AC-25, AC-37)', () {
    CollectionFilter edited(DateChoice d) => CollectionFilter(edited: d);
    test('Last 7 days is today and the 6 days before', () {
      final all = [
        s('start', edited: DateTime(2026, 10, 10, 0, 0)),
        s('before', edited: DateTime(2026, 10, 9, 23, 59), index: 1),
        s('today', edited: DateTime(2026, 10, 16, 9), index: 2),
      ];
      expect(run(all, edited(DateChoice.last7Days)), ['start', 'today']);
    });
    test('Last 30 days is today and the 29 days before', () {
      final all = [
        s('in', edited: DateTime(2026, 9, 17)),
        s('out', edited: DateTime(2026, 9, 16, 23, 59), index: 1),
      ];
      expect(run(all, edited(DateChoice.last30Days)), ['in']);
    });
    test('This year is 1 January until now', () {
      final all = [
        s('jan1', edited: DateTime(2026, 1, 1)),
        s('dec31', edited: DateTime(2025, 12, 31, 23, 59), index: 1),
        s('future', edited: DateTime(2026, 10, 16, 16), index: 2),
      ];
      expect(run(all, edited(DateChoice.thisYear)), ['jan1']);
    });
    test('custom range includes its whole first and last day', () {
      final choice = DateChoice.custom(
        DateTime(2026, 10, 1, 17),
        DateTime(2026, 10, 5, 3),
      );
      final all = [
        s('first', created: DateTime(2026, 10, 1, 0, 0)),
        s('last', created: DateTime(2026, 10, 5, 23, 59, 59), index: 1),
        s('after', created: DateTime(2026, 10, 6), index: 2),
        s('before', created: DateTime(2026, 9, 30, 23, 59), index: 3),
      ];
      expect(run(all, CollectionFilter(created: choice)), ['first', 'last']);
    });
    test('custom range with start after end is not applied (AC-21)', () {
      final choice =
          DateChoice.custom(DateTime(2026, 10, 5), DateTime(2026, 10, 1));
      final all = [s('a', created: DateTime(2026, 1, 1))];
      expect(run(all, CollectionFilter(created: choice)), ['a']);
    });
    test('created and edited are separate', () {
      final all = [
        s('x', created: DateTime(2026, 1, 1), edited: DateTime(2026, 10, 15)),
      ];
      expect(
        run(
          all,
          const CollectionFilter(
            created: DateChoice.last7Days,
            edited: DateChoice.last7Days,
          ),
        ),
        isEmpty,
      );
    });
    test('rangeProblem (AC-21)', () {
      expect(
        rangeProblem(DateTime(2026, 10, 5), DateTime(2026, 10, 1)),
        'Start must be on or before end',
      );
      expect(
          rangeProblem(DateTime(2026, 10, 1), DateTime(2026, 10, 1)), isNull);
      expect(
        rangeProblem(DateTime(2026, 10, 1, 20), DateTime(2026, 10, 1, 1)),
        isNull,
      );
    });
    test('DateChoice equality', () {
      expect(
        DateChoice.custom(DateTime(2026, 1, 1), DateTime(2026, 1, 2)),
        DateChoice.custom(DateTime(2026, 1, 1), DateTime(2026, 1, 2)),
      );
      expect(DateChoice.any, isNot(DateChoice.last7Days));
    });
  });

  group('sort (AC-37)', () {
    final all = [
      s('m',
          name: 'mango',
          index: 0,
          created: DateTime(2026, 3, 1),
          edited: DateTime(2026, 5, 1)),
      s('a',
          name: 'Apple',
          index: 2,
          created: DateTime(2026, 5, 1),
          edited: DateTime(2026, 3, 1)),
      s('b',
          name: 'banana',
          index: 1,
          created: DateTime(2026, 4, 1),
          edited: DateTime(2026, 4, 1)),
    ];
    test('My order by treeIndex', () {
      expect(run(all, const CollectionFilter()), ['m', 'b', 'a']);
    });
    test('Name A-Z ignores case', () {
      expect(
        run(all, const CollectionFilter(sort: CollectionSort.nameAZ)),
        ['a', 'b', 'm'],
      );
    });
    test('Recently edited and created, newest first', () {
      expect(
        run(all, const CollectionFilter(sort: CollectionSort.recentlyEdited)),
        ['m', 'b', 'a'],
      );
      expect(
        run(all, const CollectionFilter(sort: CollectionSort.recentlyCreated)),
        ['a', 'b', 'm'],
      );
    });
    test('ties fall back to My order', () {
      final t = [
        s('x', name: 'Same', index: 5),
        s('y', name: 'same', index: 1)
      ];
      expect(
        run(t, const CollectionFilter(sort: CollectionSort.nameAZ)),
        ['y', 'x'],
      );
    });
    test('input is not changed', () {
      final copy = [...all];
      searchCollections(
        all,
        const CollectionFilter(sort: CollectionSort.nameAZ),
        now: now,
      );
      expect(all, copy);
    });
  });

  group('tagCounts (AC-38, AC-23)', () {
    final all = [
      s('1', topic: ['Food', 'Home'], origin: ['Series']),
      s('2', topic: ['food', 'Zoo'], origin: ['Film', 'Series']),
      s('3', topic: ['Work'], srcTopic: {'sports'}),
    ];
    test('most used then A-Z, first spelling kept, per kind', () {
      expect(tagCounts(all, TagKind.topic), [
        (text: 'Food', count: 2),
        (text: 'Home', count: 1),
        (text: 'Work', count: 1),
        (text: 'Zoo', count: 1),
      ]);
      expect(tagCounts(all, TagKind.origin), [
        (text: 'Series', count: 2),
        (text: 'Film', count: 1),
      ]);
    });
    test('a duplicate inside one collection counts once', () {
      final c = [
        s('1', topic: ['Food', 'food'])
      ];
      expect(tagCounts(c, TagKind.topic), [(text: 'Food', count: 1)]);
    });
    test('no collections, no tags', () {
      expect(tagCounts(const [], TagKind.topic), isEmpty);
    });
  });

  group('useCounts', () {
    test('collection or any source, once per collection', () {
      final all = [
        s('1', topic: ['Food'], srcTopic: {'food', 'work'}),
        s('2', srcTopic: {'food'}),
        s('3', topic: ['Work']),
        s('4', origin: ['Food'], srcOrigin: {'food'}),
      ];
      expect(useCounts(all, TagKind.topic), {'food': 2, 'work': 2});
      expect(useCounts(all, TagKind.origin), {'food': 1});
    });
  });

  test('500 summaries with 2,000 tags search in 100 ms or less', () {
    final all = [
      for (var i = 0; i < 500; i++)
        s(
          'c$i',
          name: 'Collection $i',
          description: 'Description of collection number $i',
          origin: ['Origin ${i % 50}', 'Book'],
          topic: ['Topic ${i % 100}', 'Food', 'Home'],
          srcTopic: {'src ${i % 7}'},
          index: i,
          created: DateTime(2026, 1, 1).add(Duration(days: i % 280)),
          edited: DateTime(2026, 1, 1).add(Duration(days: i % 280)),
        ),
    ];
    expect(
        all.fold<int>(
            0, (n, c) => n + c.originTags.length + c.topicTags.length),
        2500);
    final sw = Stopwatch()..start();
    final r = searchCollections(
      all,
      const CollectionFilter(
        query: 'collection',
        originTags: ['Book'],
        topicTags: ['Food'],
        created: DateChoice.thisYear,
        sort: CollectionSort.recentlyEdited,
      ),
      now: now,
    );
    tagCounts(all, TagKind.topic);
    sw.stop();
    expect(r, isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThanOrEqualTo(100));
  });
}
