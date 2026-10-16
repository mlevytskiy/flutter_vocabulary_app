/// The pure search, filter, sort and tag counts of the Collections screen
/// (collection-tags, sad §6 Flow 8, ADR-0005, ADR-0006).
///
/// Plain Dart over [CollectionSummary] values the store builds — no Flutter,
/// no Isar — so it runs in memory on every keystroke and tests without either.
library;

import '../models/tag_kind.dart';
import 'tag_rules.dart';

/// One live (not binned) collection as the search sees it. Built by the
/// store; empty collections are included (AC-27).
class CollectionSummary {
  const CollectionSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.originTags,
    required this.topicTags,
    required this.sourceOriginKeys,
    required this.sourceTopicKeys,
    required this.folderPath,
    required this.treeIndex,
    required this.created,
    required this.edited,
  });

  final String id;
  final String name;
  final String description;
  final List<String> originTags;
  final List<String> topicTags;

  /// The `tagKey`s of the tags of the collection's sources, per kind.
  final Set<String> sourceOriginKeys;
  final Set<String> sourceTopicKeys;

  /// The folders above the collection, for display under its name.
  final String folderPath;

  /// The position in My order: folder by folder, each folder's collections
  /// where that folder sits (AC-37).
  final int treeIndex;

  /// The moment it was first made (AC-25).
  final DateTime created;

  /// The last change (AC-06).
  final DateTime edited;

  List<String> tagsOf(TagKind kind) =>
      kind == TagKind.origin ? originTags : topicTags;

  Set<String> sourceKeysOf(TagKind kind) =>
      kind == TagKind.origin ? sourceOriginKeys : sourceTopicKeys;
}

enum _DateKind { any, last7Days, last30Days, thisYear, custom }

/// A time choice of the filter: Any time, Last 7 days, Last 30 days, This
/// year or a custom range (AC-37).
class DateChoice {
  const DateChoice._(this._kind)
      : start = null,
        end = null;

  /// A custom range; only the calendar days of [start] and [end] count.
  const DateChoice.custom(DateTime this.start, DateTime this.end)
      : _kind = _DateKind.custom;

  static const any = DateChoice._(_DateKind.any);
  static const last7Days = DateChoice._(_DateKind.last7Days);
  static const last30Days = DateChoice._(_DateKind.last30Days);
  static const thisYear = DateChoice._(_DateKind.thisYear);

  final _DateKind _kind;
  final DateTime? start;
  final DateTime? end;

  bool get isCustom => _kind == _DateKind.custom;

  /// Whether the choice narrows anything. A custom range whose start is after
  /// its end is not applied (AC-21).
  bool get isActive =>
      _kind != _DateKind.any &&
      !(isCustom && rangeProblem(start!, end!) != null);

  /// The half-open `[from, to)` span, in local time, or null for no limit.
  (DateTime, DateTime)? _span(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (_kind) {
      case _DateKind.any:
        return null;
      case _DateKind.last7Days:
        return (
          DateTime(today.year, today.month, today.day - 6),
          DateTime(today.year, today.month, today.day + 1),
        );
      case _DateKind.last30Days:
        return (
          DateTime(today.year, today.month, today.day - 29),
          DateTime(today.year, today.month, today.day + 1),
        );
      case _DateKind.thisYear:
        // Until now: one microsecond past it so now itself is inside.
        return (
          DateTime(now.year),
          now.add(const Duration(microseconds: 1)),
        );
      case _DateKind.custom:
        if (rangeProblem(start!, end!) != null) return null;
        return (
          DateTime(start!.year, start!.month, start!.day),
          DateTime(end!.year, end!.month, end!.day + 1),
        );
    }
  }

  bool _contains(DateTime moment, DateTime now) {
    final span = _span(now);
    if (span == null) return true;
    return !moment.isBefore(span.$1) && moment.isBefore(span.$2);
  }

  @override
  bool operator ==(Object other) =>
      other is DateChoice &&
      other._kind == _kind &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(_kind, start, end);
}

enum CollectionSort { myOrder, nameAZ, recentlyEdited, recentlyCreated }

/// Shown when a custom range starts after it ends (AC-21).
const rangeProblemMessage = 'Start must be on or before end';

/// What is wrong with the custom range [start]–[end], or null. Only the
/// calendar days count, so the same day is fine.
String? rangeProblem(DateTime start, DateTime end) {
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return s.isAfter(e) ? rangeProblemMessage : null;
}

/// The search text, the picked tags, the two time choices and the sort.
class CollectionFilter {
  const CollectionFilter({
    this.query = '',
    this.originTags = const [],
    this.topicTags = const [],
    this.created = DateChoice.any,
    this.edited = DateChoice.any,
    this.sort = CollectionSort.myOrder,
  });

  final String query;
  final List<String> originTags;
  final List<String> topicTags;
  final DateChoice created;
  final DateChoice edited;
  final CollectionSort sort;

  /// Whether a search or filter is on (AC-22). The sort alone is not.
  bool get isActive =>
      query.trim().isNotEmpty ||
      originTags.isNotEmpty ||
      topicTags.isNotEmpty ||
      created.isActive ||
      edited.isActive;
}

/// The collections that match [filter], sorted (AC-19, AC-20, AC-37): the
/// query is a case-insensitive substring of the name, description or a tag;
/// every picked tag must be on the collection itself; both time choices must
/// hold, in local calendar days relative to [now]. [summaries] is not changed.
List<CollectionSummary> searchCollections(
  Iterable<CollectionSummary> summaries,
  CollectionFilter filter, {
  required DateTime now,
}) {
  final query = filter.query.trim().toLowerCase();
  final originKeys = {for (final t in filter.originTags) tagKey(t)};
  final topicKeys = {for (final t in filter.topicTags) tagKey(t)};

  bool matches(CollectionSummary c) {
    if (query.isNotEmpty &&
        !(c.name.toLowerCase().contains(query) ||
            c.description.toLowerCase().contains(query) ||
            c.originTags.any((t) => t.toLowerCase().contains(query)) ||
            c.topicTags.any((t) => t.toLowerCase().contains(query)))) {
      return false;
    }
    if (originKeys.isNotEmpty &&
        !originKeys.every(
          {for (final t in c.originTags) tagKey(t)}.contains,
        )) {
      return false;
    }
    if (topicKeys.isNotEmpty &&
        !topicKeys.every({for (final t in c.topicTags) tagKey(t)}.contains)) {
      return false;
    }
    return filter.created._contains(c.created, now) &&
        filter.edited._contains(c.edited, now);
  }

  int byOrder(CollectionSummary a, CollectionSummary b) =>
      a.treeIndex.compareTo(b.treeIndex);

  final result = summaries.where(matches).toList();
  final int Function(CollectionSummary, CollectionSummary) compare;
  switch (filter.sort) {
    case CollectionSort.myOrder:
      compare = byOrder;
    case CollectionSort.nameAZ:
      compare = (a, b) {
        final n = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return n != 0 ? n : byOrder(a, b);
      };
    case CollectionSort.recentlyEdited:
      compare = (a, b) {
        final n = b.edited.compareTo(a.edited);
        return n != 0 ? n : byOrder(a, b);
      };
    case CollectionSort.recentlyCreated:
      compare = (a, b) {
        final n = b.created.compareTo(a.created);
        return n != 0 ? n : byOrder(a, b);
      };
  }
  result.sort(compare);
  return result;
}

/// The tags of [kind] that at least one of [summaries] carries itself, with
/// the number of collections that carry each, most used first then A–Z
/// (AC-38). The spelling shown is the first met; a tag twice in one
/// collection counts once.
List<({String text, int count})> tagCounts(
  Iterable<CollectionSummary> summaries,
  TagKind kind,
) {
  final spelling = <String, String>{};
  final counts = <String, int>{};
  for (final c in summaries) {
    final own = <String>{};
    for (final text in c.tagsOf(kind)) {
      final key = tagKey(text);
      spelling.putIfAbsent(key, () => text);
      if (own.add(key)) counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final list = [
    for (final e in counts.entries) (text: spelling[e.key]!, count: e.value),
  ];
  list.sort((a, b) {
    final n = b.count.compareTo(a.count);
    return n != 0 ? n : a.text.toLowerCase().compareTo(b.text.toLowerCase());
  });
  return list;
}

/// For the tag library: how many collections use each tag key of [kind], on
/// the collection or on any of its sources, a collection counting once.
Map<String, int> useCounts(
  Iterable<CollectionSummary> summaries,
  TagKind kind,
) {
  final counts = <String, int>{};
  for (final c in summaries) {
    final keys = {
      for (final t in c.tagsOf(kind)) tagKey(t),
      ...c.sourceKeysOf(kind),
    };
    for (final k in keys) {
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  return counts;
}
