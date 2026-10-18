import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/models/tag_library_entry.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search.dart';
import 'package:flutter_vocabulary_app/features/tags/tag_suggestions.dart';

/// collection-tags T7 (AC-35, AC-38, ADR-0009): the tagSuggestions provider
/// ranks the library by use in the live collections, then the presets.
void main() {
  TagLibraryEntry entry(TagKind kind, String text,
          {DateTime? used, bool forgotten = false}) =>
      TagLibraryEntry()
        ..kind = kind
        ..key = text.trim().toLowerCase()
        ..text = text
        ..lastUsedAt = used
        ..forgotten = forgotten;

  CollectionSummary summary(String id, {List<String> topic = const []}) =>
      CollectionSummary(
        id: id,
        name: id,
        description: '',
        originTags: const [],
        topicTags: topic,
        sourceOriginKeys: const {},
        sourceTopicKeys: const {},
        folderPath: 'Top level',
        treeIndex: 0,
        created: DateTime(2026),
        edited: DateTime(2026),
      );

  ProviderContainer containerWith(
      List<TagLibraryEntry> library, List<CollectionSummary> summaries) {
    final c = ProviderContainer(overrides: [
      tagLibraryProvider.overrideWith((ref) => Stream.value(library)),
      collectionSummariesProvider
          .overrideWith((ref) => Stream.value(summaries)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<List<String>> texts(ProviderContainer c, TagKind kind,
      {String query = ''}) async {
    await c.read(tagLibraryProvider.future);
    await c.read(collectionSummariesProvider.future);
    return [
      for (final s in c.read(tagSuggestionsProvider(kind, query: query)))
        s.text,
    ];
  }

  test('used tags first by count, then unused by recency, then presets',
      () async {
    final c = containerWith([
      entry(TagKind.topic, 'Rare', used: DateTime(2026, 1, 1)),
      entry(TagKind.topic, 'Common', used: DateTime(2026, 1, 2)),
      entry(TagKind.topic, 'Idle', used: DateTime(2026, 5, 1)),
      entry(TagKind.topic, 'Older idle', used: DateTime(2026, 3, 1)),
      entry(TagKind.origin, 'Elsewhere'),
    ], [
      summary('a', topic: ['Common', 'Rare']),
      summary('b', topic: ['common']),
    ]);
    final list = await texts(c, TagKind.topic);
    expect(list.take(4), ['Common', 'Rare', 'Idle', 'Older idle']);
    expect(list, isNot(contains('Elsewhere')));
    expect(list, contains('Food')); // a preset follows the library
    final presets = c.read(tagSuggestionsProvider(TagKind.topic));
    expect(presets.firstWhere((s) => s.text == 'Food').isPreset, isTrue);
    expect(presets.first.isPreset, isFalse);
  });

  test('forgotten tags are not suggested', () async {
    final c = containerWith([
      entry(TagKind.topic, 'Gone', forgotten: true),
      entry(TagKind.topic, 'Here'),
    ], const []);
    final list = await texts(c, TagKind.topic);
    expect(list, contains('Here'));
    expect(list, isNot(contains('Gone')));
  });

  test('tags of binned collections count zero (not in the summaries)',
      () async {
    // 'Binned' is only on a collection the summaries leave out, 'Live' on one
    // that is there: Live ranks first although it was used earlier.
    final c = containerWith([
      entry(TagKind.topic, 'Binned', used: DateTime(2026, 9, 1)),
      entry(TagKind.topic, 'Live', used: DateTime(2026, 1, 1)),
    ], [
      summary('a', topic: ['Live']),
    ]);
    final list = await texts(c, TagKind.topic);
    expect(list.take(2), ['Live', 'Binned']);
  });

  test('the query matches by word start', () async {
    final c = containerWith([
      entry(TagKind.topic, 'Street food'),
      entry(TagKind.topic, 'Cooking'),
    ], const []);
    final list = await texts(c, TagKind.topic, query: 'foo');
    expect(list.first, 'Street food');
    expect(list, isNot(contains('Cooking')));
  });
}
