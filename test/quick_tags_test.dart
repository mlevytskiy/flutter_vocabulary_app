import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search_scope.dart';

/// filter-sheet-pills (owner, 2026-10-18): the filter sheet's Popular line
/// and the recent filter tags behind it.

CollectionSummary _s(String id,
        {List<String> origin = const [], List<String> topic = const []}) =>
    CollectionSummary(
      id: id,
      name: id,
      description: '',
      originTags: origin,
      topicTags: topic,
      sourceOriginKeys: const {},
      sourceTopicKeys: const {},
      folderPath: 'Top level',
      treeIndex: 0,
      created: DateTime(2026),
      edited: DateTime(2026),
    );

QuickTag _o(String t) => (kind: TagKind.origin, text: t);
QuickTag _t(String t) => (kind: TagKind.topic, text: t);

void main() {
  // Use: Film 3, Food 2, Quizlet 2, Verbs 1, Travel 1, Photo 1.
  final all = [
    _s('a', origin: ['Film'], topic: ['Food']),
    _s('b', origin: ['Film', 'Quizlet'], topic: ['Food', 'Verbs']),
    _s('c', origin: ['Film', 'Quizlet', 'Photo'], topic: ['Travel']),
  ];

  group('quickTags', () {
    test('nothing with 4 tags or fewer, or none', () {
      expect(quickTags(const [], const []), isEmpty);
      final four = [
        _s('a', origin: ['A', 'B'], topic: ['C', 'D'])
      ];
      expect(quickTags(four, [_o('A')]), isEmpty);
    });

    test('no recent searches: the 4 most used', () {
      expect(quickTags(all, const []),
          [_o('Film'), _t('Food'), _o('Quizlet'), _o('Photo')]);
    });

    test('2 recent first, then the most used, no repeats', () {
      expect(quickTags(all, [_t('travel'), _o('Film'), _t('Verbs')]),
          [_t('Travel'), _o('Film'), _t('Food'), _o('Quizlet')]);
    });

    test('a recent tag no longer in use, or of the other kind, is skipped', () {
      expect(quickTags(all, [_o('Gone'), _t('Film'), _t('Verbs')]),
          [_t('Verbs'), _o('Film'), _t('Food'), _o('Quizlet')]);
    });
  });

  group('RecentFilterTagsNotifier', () {
    test('record moves to the front, dedupes by kind and key, persists',
        () async {
      SharedPreferences.setMockInitialValues({
        RecentFilterTagsNotifier.prefsKey: ['origin|Film', 'topic|Food'],
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(recentFilterTagsProvider.notifier);
      await n.loaded;
      expect(c.read(recentFilterTagsProvider), [_o('Film'), _t('Food')]);
      await n.record([_t('food'), _o('Photo')]);
      expect(c.read(recentFilterTagsProvider),
          [_t('food'), _o('Photo'), _o('Film')]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(RecentFilterTagsNotifier.prefsKey),
          ['topic|food', 'origin|Photo', 'origin|Film']);
    });

    test('keeps at most 10', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(recentFilterTagsProvider.notifier);
      await n.loaded;
      await n.record([for (var i = 0; i < 12; i++) _o('t$i')]);
      expect(c.read(recentFilterTagsProvider), hasLength(10));
    });
  });
}
