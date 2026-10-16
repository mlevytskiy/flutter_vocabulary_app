import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/session_source.dart';
import '../../core/models/word_collection.dart';
import '../../core/models/word_pair.dart';

part 'include_photos.g.dart';

/// The "Include photos (N)" switch, now in the Words screen's settings
/// (words-photo-panel): on until switched off, for the Words screen of
/// [collectionId] (null: the current collection). Not saved: it lives while
/// that Words screen does, which watches it, as it did in its `State`.
/// Sets (import-from-quizlet) are not behind it: they are always sent.
@riverpod
class IncludePhotos extends _$IncludePhotos {
  @override
  bool build(String? collectionId) => true;

  void set(bool value) => state = value;
}

/// The sources a link may carry: photos and sets with a linked row that
/// will be published (AC-15, AC-23).
List<SessionSource> linkedSources(
    WordCollection? collection, List<WordPair> wordPairs) {
  final linkedIds = {for (final pair in wordPairs) pair.sourceId};
  return (collection?.sources ?? const <SessionSource>[])
      .where((source) => linkedIds.contains(source.id))
      .toList();
}

/// The photos among [sources]: "Include photos (N)" counts them; with none
/// the switch is not shown. Sets are always published (AC-15).
List<SessionSource> linkedPhotos(List<SessionSource> sources) => [
      for (final source in sources)
        if (source.kind == SourceKind.photo) source,
    ];

/// The rows the Words screen lists and shares: every filled row -- a word
/// plus a translation or a definition -- whatever the mode (definition-mode
/// spec AC-12).
List<WordPair> filledPairs(WordCollection? collection) =>
    (collection?.words ?? const <WordPair>[])
        .where((pair) => pair.isFilled)
        .toList();
