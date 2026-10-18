/// The legacy fallback of collection-tags (sad §8, ADR-0003): until the
/// one-time migration has succeeded, a record whose typed lists are both
/// empty and whose legacy `tags` are not reads its legacy tags as topic tags,
/// so a failed migration never shows a tagged collection as having none.
///
/// Pure: reads the records, never writes them.
library;

import 'session_source.dart';
import 'word_collection.dart';

/// The tags to show for typed lists [origin] and [topic] beside the legacy
/// list [legacy]: the typed lists as they are, unless both are empty and
/// [legacy] is not, then no origin tags and [legacy] as the topic tags.
({List<String> origin, List<String> topic}) effectiveTags({
  required List<String> origin,
  required List<String> topic,
  required List<String> legacy,
}) {
  if (origin.isEmpty && topic.isEmpty && legacy.isNotEmpty) {
    return (origin: const [], topic: List.unmodifiable(legacy));
  }
  return (origin: origin, topic: topic);
}

/// [effectiveTags] of a collection's own tags (its sources' not included).
({List<String> origin, List<String> topic}) effectiveTagsOf(WordCollection c) =>
    effectiveTags(origin: c.originTags, topic: c.topicTags, legacy: c.tags);

/// [effectiveTags] of a source's own tags.
({List<String> origin, List<String> topic}) effectiveSourceTagsOf(
        SessionSource s) =>
    effectiveTags(origin: s.originTags, topic: s.topicTags, legacy: s.tags);
