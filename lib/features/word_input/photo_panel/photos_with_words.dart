import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/session_source.dart';
import '../word_input_notifier.dart';

part 'photos_with_words.g.dart';

/// A photo of the current session and the positions of the word rows that
/// still come from it, in the list's current order (CONTEXT "photo with words").
typedef PhotoWithWords = ({SessionSource source, List<int> rows});

/// The current session's photos with words, oldest first (the order of
/// `Session.sources`), derived in one pass over the rows (sad §4). Only the
/// current session is read, so another session's photos never appear
/// (spec AC-16); a set is never listed, and a row whose word is cleared does
/// not count (spec AC-15).
@riverpod
List<PhotoWithWords> photosWithWords(Ref ref) {
  final session = ref.watch(wordInputNotifierProvider).valueOrNull;
  if (session == null) return const [];
  final rowsBySource = <String, List<int>>{};
  for (var i = 0; i < session.words.length; i++) {
    final pair = session.words[i];
    final id = pair.sourceId;
    if (id == null || pair.word.trim().isEmpty) continue;
    (rowsBySource[id] ??= []).add(i);
  }
  return [
    for (final source in session.sources)
      if (source.kind == SourceKind.photo && rowsBySource[source.id] != null)
        (source: source, rows: rowsBySource[source.id]!),
  ];
}
