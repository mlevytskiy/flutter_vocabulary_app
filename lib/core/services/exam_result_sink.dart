import '../models/word_collection.dart';
import '../models/word_result.dart';
import 'collection_store.dart';

/// Where Step 3 exams put their word results (learn-kit H-05, S-23). An exam
/// calls [record] as soon as a word's result is final (D-32), not at the end
/// of the round; a word never examined gets nothing. Only Step 3 exercises
/// write. Reading goes through [latest].
abstract interface class ExamResultSink {
  /// Saves [label] for the word [rowId] of the session [collectionId] (null is
  /// the current session) from the exam [exerciseId], now. An empty [rowId]
  /// is not written. Never throws.
  Future<void> record({
    required String? collectionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  });

  /// Each word's current result: its most recent one from any exam, by rowId.
  /// Results whose word row is gone are left out (AC-37).
  Map<String, WordResult> latest(WordCollection collection);
}

/// The sink over [CollectionStore] (S-23): it writes for the current session
/// and History sessions alike, because a result is not a word edit — neither
/// time of the session moves (AC-37).
class StoreExamResultSink implements ExamResultSink {
  StoreExamResultSink(this._store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Future<CollectionStore> Function() _store;
  final DateTime Function() _clock;

  @override
  Future<void> record({
    required String? collectionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  }) async {
    if (rowId.isEmpty) return;
    try {
      final store = await _store();
      final id = collectionId ?? await store.currentCollectionId();
      if (id == null) return;
      await store.appendResult(
        id,
        WordResult()
          ..rowId = rowId
          ..exerciseId = exerciseId
          ..label = label
          ..at = _clock(),
      );
    } catch (_) {
      // A lost result is a word with no label (AC-36), never a crash.
    }
  }

  @override
  Map<String, WordResult> latest(WordCollection collection) {
    final rows = {for (final w in collection.words) if (w.rowId.isNotEmpty) w.rowId};
    return {
      for (final r in collection.results)
        if (rows.contains(r.rowId)) r.rowId: r,
    };
  }
}
