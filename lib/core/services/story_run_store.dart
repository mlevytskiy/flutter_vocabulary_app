import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/session.dart';
import '../models/story_run.dart';

/// Persists story runs (mnemonic-story, ADR-0003) in the same Isar database
/// as the sessions (`vocab`).
///
/// A story run is a record for comparing AIs: this store has no delete, so a
/// newer story or a changed group never removes one (AC-15). Like
/// `SessionStore`, nothing here throws: a bad read gives null or an empty
/// list, a bad write is dropped.
class StoryRunStore {
  final Isar _isar;

  StoryRunStore._(this._isar);

  static Future<StoryRunStore> open({String? directory}) async {
    final dir = directory ?? (await getApplicationDocumentsDirectory()).path;
    final isar = Isar.getInstance('vocab') ??
        await Isar.open([SessionSchema, StoryRunSchema],
            directory: dir, name: 'vocab');
    return StoryRunStore._(isar);
  }

  /// Upsert on [StoryRun.runId].
  Future<void> put(StoryRun run) async {
    try {
      await _isar.writeTxn(() async {
        run.id = await _isar.storyRuns.put(run);
      });
    } catch (_) {
      // ignored on purpose, see the class doc
    }
  }

  Future<StoryRun?> byId(String runId) async {
    try {
      return await _isar.storyRuns.getByRunId(runId);
    } catch (_) {
      return null;
    }
  }

  /// Every run, newest [StoryRun.startedAt] first.
  Future<List<StoryRun>> newestFirst() async {
    try {
      return await _isar.storyRuns.where().sortByStartedAtDesc().findAll();
    } catch (_) {
      return const [];
    }
  }

  /// Runs whose results the app has not yet copied to the phone, newest first.
  Future<List<StoryRun>> uncollected() async {
    try {
      return await _isar.storyRuns
          .filter()
          .collectedEqualTo(false)
          .sortByStartedAtDesc()
          .findAll();
    } catch (_) {
      return const [];
    }
  }

  /// Emits the run now and after every write to the collection (null while
  /// unknown). Re-reads by run id, because a put of a new object with the same
  /// run id replaces the row under a new Isar id.
  Stream<StoryRun?> watch(String runId) => _isar.storyRuns
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => byId(runId));

  /// Emits every run, newest first, now and after every write to the
  /// collection: the story screen picks the runs of its group from it.
  Stream<List<StoryRun>> watchNewestFirst() => _isar.storyRuns
      .watchLazy(fireImmediately: true)
      .asyncMap((_) => newestFirst());
}
