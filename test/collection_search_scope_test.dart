import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search_scope.dart';

/// collections-search (AC-03, AC-05, AC-06, AC-09): the split by the open
/// folder, the route and the live tag counts, without Flutter or Isar.

CollectionSummary _c(String id, String? folderId, int index,
        {List<String> topic = const []}) =>
    CollectionSummary(
      id: id,
      name: id,
      description: '',
      originTags: const [],
      topicTags: topic,
      sourceOriginKeys: const {},
      sourceTopicKeys: const {},
      folderPath: '',
      folderId: folderId,
      treeIndex: index,
      created: DateTime(2026, 10, 1),
      edited: DateTime(2026, 10, 1),
    );

void main() {
  const folders = [
    SearchFolder(id: 'lang', name: 'Languages', parentId: null, order: 0),
    SearchFolder(id: 'es', name: 'Spain', parentId: 'lang', order: 0),
    SearchFolder(id: 'en', name: 'English', parentId: 'lang', order: 1),
    SearchFolder(id: 'vd', name: 'Verb drills', parentId: 'en', order: 0),
    SearchFolder(id: 'films', name: 'Films', parentId: null, order: 1),
  ];
  final results = [
    _c('tenses', 'lang', 0),
    _c('spverbs', 'es', 1),
    _c('phrasal', 'en', 2),
    _c('modal', 'vd', 3),
    _c('friends', 'films', 4),
    _c('cooking', null, 5),
  ];
  const verb = CollectionFilter(query: 'verb');

  SearchSplit split(String? open, [CollectionFilter filter = verb]) =>
      splitByLevel(
        results: results,
        folders: folders,
        openFolderId: open,
        filter: filter,
      );

  List<String> ids(List<CollectionSummary> list) =>
      [for (final c in list) c.id];

  test('AC-03/AC-05: at the top level everything outside is deeper', () {
    final s = split(null);
    expect(ids(s.hereCollections), ['cooking']);
    expect(s.hereFolders, isEmpty);
    expect(ids(s.outsideCollections),
        ['tenses', 'spverbs', 'phrasal', 'modal', 'friends']);
    expect([for (final f in s.outsideFolders) f.id], ['vd']);
    expect(s.deeper, 6);
    expect(s.elsewhere, 0);
  });

  test('AC-05: inside Languages, deeper and elsewhere', () {
    final s = split('lang');
    expect(ids(s.hereCollections), ['tenses']);
    expect(s.deeper, 4); // spverbs, phrasal, modal + the Verb drills folder
    expect(s.elsewhere, 2); // friends, cooking
  });

  test('AC-03: a folder directly here whose name matches is here', () {
    final s = split('en');
    expect([for (final f in s.hereFolders) f.id], ['vd']);
    expect(s.outsideFolders, isEmpty);
  });

  test('AC-03: folders match only by a query with nothing else narrowing', () {
    final s = split(
        null, const CollectionFilter(query: 'verb', topicTags: ['grammar']));
    expect(s.hereFolders, isEmpty);
    expect(s.outsideFolders, isEmpty);
    expect(split(null, const CollectionFilter(topicTags: ['x'])).outsideFolders,
        isEmpty);
  });

  test('a collection in a folder that is not live counts as top level', () {
    final s = splitByLevel(
      results: [_c('lost', 'gone', 0)],
      folders: folders,
      openFolderId: null,
      filter: verb,
    );
    expect(ids(s.hereCollections), ['lost']);
  });

  test('AC-06: the route from Languages, pruned, rails drawn', () {
    final s = split('lang');
    final route = matchRoute(split: s, folders: folders, openFolderId: 'lang');
    String label(RouteRow r) => switch (r.kind) {
          RouteRowKind.root => 'root',
          RouteRowKind.folder => r.folder!.id,
          RouteRowKind.collection => r.collection!.id,
        };
    expect([
      for (final r in route) label(r)
    ], [
      'root',
      'lang',
      'es',
      'spverbs',
      'en',
      'vd',
      'modal',
      'phrasal',
      'films',
      'friends',
      'cooking',
    ]);
    final by = {for (final r in route) label(r): r};
    expect(by['root']!.isHere, isFalse);
    expect(by['lang']!.isHere, isTrue);
    expect(by['lang']!.count, 4);
    expect(by['vd']!.nameMatches, isTrue);
    expect(by['tenses'], isNull); // directly here: in the list, not the route
    const p = RailCell.pass, n = RailCell.none;
    const t = RailCell.tee, e = RailCell.elbow;
    expect(by['lang']!.rail, [t]);
    expect(by['es']!.rail, [p, t]);
    expect(by['spverbs']!.rail, [p, p, e]);
    expect(by['en']!.rail, [p, e]);
    expect(by['vd']!.rail, [p, n, t]);
    expect(by['modal']!.rail, [p, n, p, e]);
    expect(by['phrasal']!.rail, [p, n, e]);
    expect(by['films']!.rail, [t]);
    expect(by['friends']!.rail, [p, e]);
    expect(by['cooking']!.rail, [e]);

    expect(outsidePlaces(route), ['es', 'en', 'vd', 'films', null]);
  });

  test('AC-06: at the top level the root is "You are here"', () {
    final route =
        matchRoute(split: split(null), folders: folders, openFolderId: null);
    expect(route.first.kind, RouteRowKind.root);
    expect(route.first.isHere, isTrue);
    expect(route.where((r) => r.collection?.id == 'cooking'), isEmpty);
  });

  test('folderPathOf', () {
    expect(folderPathOf('vd', folders), 'Languages / English / Verb drills');
    expect(folderPathOf(null, folders), 'Top level');
  });

  test('AC-09: live counts keep the overall order and count the matches', () {
    final all = [
      _c('a', null, 0, topic: ['Food']),
      _c('b', null, 1, topic: ['Food', 'Idioms']),
      _c('c', null, 2, topic: ['Travel']),
    ];
    final live = liveTagCounts(all, [all[2]], TagKind.topic);
    expect(live, [
      (text: 'Food', count: 0),
      (text: 'Idioms', count: 0),
      (text: 'Travel', count: 1),
    ]);
  });
}
