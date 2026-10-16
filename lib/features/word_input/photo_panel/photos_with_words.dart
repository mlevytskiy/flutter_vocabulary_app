import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/session_source.dart';
import '../word_input_notifier.dart';

part 'photos_with_words.g.dart';

/// A source of the current session and the positions of the word rows that
/// still come from it, in the list's current order (CONTEXT "photo with
/// words"; side-panel-sources: a Quizlet set with words is one too).
typedef SourceWithWords = ({SessionSource source, List<int> rows});

/// A [SourceWithWords] whose source is a photo.
typedef PhotoWithWords = SourceWithWords;

/// The source kinds the photo panel lists (side-panel-sources, spec AC-21,
/// AC-22: film subtitles).
/// A photo is drawn from its kept file; every other kind is a tile with its
/// icon and name (`SourceTile`). To list a new kind, add it here and give it
/// an icon and a screen-reader name in `SourceTile`.
const panelSourceKinds = {SourceKind.photo, SourceKind.set, SourceKind.subtitles};

extension SourceWithWordsKind on SourceWithWords {
  /// A photo has a picture; every other kind is shown as a tile, and only
  /// photos are shown large in full-open (spec AC-21).
  bool get isPhoto => source.kind == SourceKind.photo;
}

/// The current session's sources with words that the photo panel lists,
/// photos and sets mixed, oldest first by `takenAt` (sources added at the
/// same time keep the order of `WordCollection.sources`), derived in one pass over
/// the rows (sad §4). Only the current session is read, so another session's
/// sources never appear (spec AC-16); a row whose word is cleared does not
/// count (spec AC-15).
@riverpod
List<SourceWithWords> sourcesWithWords(Ref ref) {
  final collection = ref.watch(wordInputNotifierProvider).valueOrNull;
  if (collection == null) return const [];
  final rowsBySource = <String, List<int>>{};
  for (var i = 0; i < collection.words.length; i++) {
    final pair = collection.words[i];
    final id = pair.sourceId;
    if (id == null || pair.word.trim().isEmpty) continue;
    (rowsBySource[id] ??= []).add(i);
  }
  final listed = [
    for (final (i, source) in collection.sources.indexed)
      if (panelSourceKinds.contains(source.kind) &&
          rowsBySource[source.id] != null)
        (i, (source: source, rows: rowsBySource[source.id]!)),
  ];
  listed.sort((a, b) {
    final byTime = a.$2.source.takenAt.compareTo(b.$2.source.takenAt);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [for (final (_, item) in listed) item];
}

/// The current session's photos with words, oldest first: the photos of
/// [sourcesWithWords]. Full-open shows only these (spec AC-21).
@riverpod
List<PhotoWithWords> photosWithWords(Ref ref) => [
      for (final item in ref.watch(sourcesWithWordsProvider))
        if (item.isPhoto) item,
    ];
