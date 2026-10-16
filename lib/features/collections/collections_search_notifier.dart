import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/tag_kind.dart';
import '../../core/services/collection_search.dart';

part 'collections_search_notifier.g.dart';

/// The search and filter of the Collections screen (collection-tags SCR-05).
@immutable
class CollectionsSearchState {
  const CollectionsSearchState({
    this.searching = false,
    this.filter = const CollectionFilter(),
    this.enteredFromTag = false,
  });

  /// The search field is open in the top bar.
  final bool searching;

  /// The query, the picked tags, the time choices and the sort.
  final CollectionFilter filter;

  /// The screen was opened by a tag tap on the main screen (AC-14, AC-39):
  /// Back then pops straight to the main screen.
  final bool enteredFromTag;

  /// The flat results show instead of the folder view (AC-19, AC-22).
  bool get showsResults => filter.isActive;

  CollectionsSearchState copyWith({
    bool? searching,
    CollectionFilter? filter,
    bool? enteredFromTag,
  }) =>
      CollectionsSearchState(
        searching: searching ?? this.searching,
        filter: filter ?? this.filter,
        enteredFromTag: enteredFromTag ?? this.enteredFromTag,
      );
}

/// Holds the Collections screen's search, seeded from the route's tag
/// (collection-tags ADR-0008): a tag filters by that kind only, sorted My
/// order (ux-flows, "SCR-05 sort when opened from a tag").
@riverpod
class CollectionsSearch extends _$CollectionsSearch {
  @override
  CollectionsSearchState build(TagKind? tagKind, String? tag) {
    final text = tag?.trim() ?? '';
    if (tagKind == null || text.isEmpty) return const CollectionsSearchState();
    return CollectionsSearchState(
      enteredFromTag: true,
      filter: CollectionFilter(
        originTags: tagKind == TagKind.origin ? [text] : const [],
        topicTags: tagKind == TagKind.topic ? [text] : const [],
      ),
    );
  }

  /// Opens the search field in the top bar.
  void openSearch() => state = state.copyWith(searching: true);

  /// The live query, as the learner types.
  void setQuery(String query) =>
      state = state.copyWith(filter: _with(query: query));

  /// Replaces the whole filter, e.g. from the filter sheet (T14).
  void setFilter(CollectionFilter filter) =>
      state = state.copyWith(filter: filter);

  /// Removes one picked tag (its chip's ×).
  void removeTag(TagKind kind, String text) {
    final f = state.filter;
    state = state.copyWith(
      filter: _with(
        originTags: kind == TagKind.origin
            ? [
                for (final t in f.originTags)
                  if (t != text) t
              ]
            : null,
        topicTags: kind == TagKind.topic
            ? [
                for (final t in f.topicTags)
                  if (t != text) t
              ]
            : null,
      ),
    );
  }

  void clearCreated() =>
      state = state.copyWith(filter: _with(created: DateChoice.any));

  void clearEdited() =>
      state = state.copyWith(filter: _with(edited: DateChoice.any));

  /// Clear / Clear filters: drops the query and every filter and closes the
  /// field; the folder view comes back (AC-24, AC-39).
  void clear() => state = state.copyWith(
        searching: false,
        filter: const CollectionFilter(),
      );

  CollectionFilter _with({
    String? query,
    List<String>? originTags,
    List<String>? topicTags,
    DateChoice? created,
    DateChoice? edited,
  }) {
    final f = state.filter;
    return CollectionFilter(
      query: query ?? f.query,
      originTags: originTags ?? f.originTags,
      topicTags: topicTags ?? f.topicTags,
      created: created ?? f.created,
      edited: edited ?? f.edited,
      sort: f.sort,
    );
  }
}
