import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/tag_kind.dart';
import '../../core/providers.dart';
import '../../core/services/collection_search.dart' show useCounts;
import '../../core/services/tag_rules.dart';

part 'tag_suggestions.g.dart';

/// The suggestions for a tag field of [kind] matching [query] (AC-35): the
/// tag library ranked by use in the live collections, then the presets.
/// Tags already on the field are not removed here; the widgets filter them.
@riverpod
List<TagSuggestion> tagSuggestions(Ref ref, TagKind kind, {String query = ''}) {
  final library = ref.watch(tagLibraryProvider).value ?? const [];
  final summaries =
      ref.watch(collectionSummariesProvider).value ?? const [];
  return rankSuggestions(
    kind: kind,
    library: [
      for (final e in library)
        (
          kind: e.kind,
          text: e.text,
          lastUsedAt: e.lastUsedAt,
          forgotten: e.forgotten,
        ),
    ],
    counts: useCounts(summaries, kind),
    presets: presetsFor(kind),
    added: const [],
    query: query,
  );
}
