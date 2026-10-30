import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/services/collection_store.dart';
import 'leitner.dart';

part 'session_result.g.dart';

/// What a finished learning session or talk hands the shared results screen
/// (learn-redesign sad §5.1 "SessionResult holder", §6.3; AC-12, AC-22).

/// Which kind of session produced a result: the results screen adds the
/// "N words not used — unchanged" line for a talk (AC-22).
enum SessionKind { exercises, talk }

/// One finished session: its box [moves] (one per word, with known / shaky /
/// new / unused), whether they were [written] to the store (false when the
/// collection was erased meanwhile, sad §6.3), and the session group it
/// played ([groupIndex] null and [groupCount] 0 when not split).
class SessionResult {
  const SessionResult({
    required this.kind,
    required this.collectionId,
    required this.moves,
    required this.unusedCount,
    required this.written,
    this.groupIndex,
    this.groupCount = 0,
    this.pages = 0,
  });

  final SessionKind kind;

  /// The collection the session played; null when there was none to resolve.
  final String? collectionId;
  final List<SessionMove> moves;

  /// How many of a talk's words were never used (AC-22); 0 for exercises.
  final int unusedCount;
  final bool written;
  final int? groupIndex;
  final int groupCount;

  /// Exercise pages played; 0 for a talk.
  final int pages;
}

/// The last finished session, read by the results screen (sad §5.1). Written
/// by the learning session and by Talk at their end; kept alive so the
/// results screen and "Practise N shaky" / "Next group" can read it.
@Riverpod(keepAlive: true)
class LastSessionResult extends _$LastSessionResult {
  @override
  SessionResult? build() => null;

  void set(SessionResult result) => state = result;
}

/// Moves a finished session's boxes in ONE store transaction (ADR-0002,
/// sad §6.3, AC-13, AC-22): [applySession] runs inside
/// `CollectionStore.update` on the stored boxes, dropping boxes of rows no
/// longer in the collection. A null [collectionId] is the current collection.
/// When the collection is gone the moves are worked out on the boxes read
/// before and nothing is written ([SessionResult.written] false). [outcomes]
/// and [ratings] (the flagged words' self-check ratings, self-check-cards
/// AC-05 – AC-09) are keyed by the session's own [WordPair] instances.
Future<SessionResult> finishSession({
  required CollectionStore store,
  required String? collectionId,
  required Map<WordPair, WordOutcome> outcomes,
  Map<WordPair, WordRating> ratings = const {},
  required SessionKind kind,
  DateTime? now,
  int? groupIndex,
  int groupCount = 0,
  int pages = 0,
}) async {
  final at = now ?? DateTime.now();
  final id = collectionId ?? await store.currentCollectionId();
  final unused = outcomes.values.where((o) => o == WordOutcome.unused).length;
  SessionResult result(List<SessionMove> moves, bool written) => SessionResult(
        kind: kind,
        collectionId: id,
        moves: moves,
        unusedCount: unused,
        written: written,
        groupIndex: groupIndex,
        groupCount: groupCount,
        pages: pages,
      );

  if (id == null) return result(applySession(const [], outcomes, at, ratings: ratings).moves, false);
  final before = await store.byId(id);
  List<SessionMove>? moves;
  final written = await store.update(id, (c) {
    final r = applySession(c.boxes, outcomes, at, ratings: ratings, liveRowIds: {
      for (final w in c.words)
        if (w.rowId.isNotEmpty) w.rowId
    });
    c.boxes = r.boxes;
    moves = r.moves;
  });
  if (written && moves != null) return result(moves!, true);
  return result(applySession(before?.boxes ?? const [], outcomes, at, ratings: ratings).moves, false);
}
