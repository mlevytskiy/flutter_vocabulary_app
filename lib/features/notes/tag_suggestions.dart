import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/word_collection.dart';
import '../../core/providers.dart';
import '../word_input/word_input_notifier.dart';

part 'tag_suggestions.g.dart';

/// The tags already used on sources (a photo, a set, a film) in every
/// session, most used first: what the Notes page suggests for a source's
/// tag (notes-editing, owner 2026-10-15). A collection's own tags are a separate pool.
@riverpod
List<String> sourceTagSuggestions(Ref ref) => _byUse([
      for (final collection in _collections(ref))
        for (final source in collection.sources) ...source.tags,
    ]);

/// The tags already given to whole sessions, most used first.
@riverpod
List<String> collectionTagSuggestions(Ref ref) => _byUse([
      for (final collection in _collections(ref)) ...collection.tags,
    ]);

/// The stored sessions, with the current one as it is now in place of its
/// stored copy.
List<WordCollection> _collections(Ref ref) {
  final current = ref.watch(wordInputNotifierProvider).valueOrNull;
  final stored =
      ref.watch(nonEmptyCollectionsProvider).valueOrNull ?? const <WordCollection>[];
  return [
    if (current != null) current,
    for (final s in stored)
      if (s.collectionId != current?.collectionId) s,
  ];
}

/// Each tag once, the most used first, then alphabetically.
List<String> _byUse(List<String> tags) {
  final counts = <String, int>{};
  for (final tag in tags) {
    counts[tag] = (counts[tag] ?? 0) + 1;
  }
  return counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
    });
}
