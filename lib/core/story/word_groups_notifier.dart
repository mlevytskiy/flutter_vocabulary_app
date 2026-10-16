import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/word_input/word_input_notifier.dart';
import '../models/word_collection.dart';
import '../models/word_group.dart';
import '../providers.dart';
import 'story_run_tracker.dart';
import 'word_grouping.dart';

part 'word_groups_notifier.g.dart';

/// Where grouping of a session stands (mnemonic-story, sad §6 S-01).
sealed class GroupingStatus {
  const GroupingStatus();
}

/// Nothing is going and the groups are as good as they get.
class GroupingIdle extends GroupingStatus {
  const GroupingIdle();
}

/// The Worker is splitting the session's words (AC-03): the learn page shows
/// "Grouping your words…".
class GroupingInProgress extends GroupingStatus {
  const GroupingInProgress();
}

/// The call failed or the split was not valid: "Could not group your words"
/// with "Try again" (AC-04).
class GroupingFailed extends GroupingStatus {
  const GroupingFailed();
}

/// [count] words wait for a group; at least 7 are needed (AC-05).
class GroupingWaiting extends GroupingStatus {
  final int count;
  const GroupingWaiting(this.count);
}

class WordGroupsState {
  final GroupingStatus status;

  /// The session's groups; empty until [WordGroupsNotifier.ensureGrouped] has
  /// run, and while grouping failed (AC-04).
  final List<WordGroup> groups;

  /// The group the learn page shows as selected, if the session has any.
  final String? selectedGroupId;

  const WordGroupsState({
    this.status = const GroupingIdle(),
    this.groups = const [],
    this.selectedGroupId,
  });

  /// With any dialogue group the learn page always shows the group pager,
  /// however few words the session has (get-words-from-subtitles-improvment
  /// AC-25).
  bool get hasDialogueGroups => groups.any((g) => g.dialogueId != null);
}

/// Asks the story run tracker to start a run for a group that has neither a
/// story nor a run (AC-06). Tests replace it with `overrideWithValue`.
typedef StoryRunStartHook = Future<void> Function(String collectionId, WordGroup group);

final storyRunStartHookProvider = Provider<StoryRunStartHook>((ref) => (collectionId, group) async {
      await ref.read(storyRunTrackerProvider.notifier).startFor(collectionId, group);
    });

/// The groups of one session and the learner's selection among them. A null
/// [collectionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.
@Riverpod(keepAlive: true)
class WordGroupsNotifier extends _$WordGroupsNotifier {
  Future<void>? _inFlight;
  bool _disposed = false;

  @override
  WordGroupsState build(String? collectionId) {
    // The notifier object outlives a rebuild, so the flag is reset here.
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const WordGroupsState();
  }

  /// Groups the session when its words to learn changed since the last
  /// grouping, saves the result and publishes it. A second call while one is
  /// going shares it. Never throws.
  Future<void> ensureGrouped() =>
      _inFlight ??= _ensureGrouped().whenComplete(() => _inFlight = null);

  /// Makes [groupId] the selected group and saves it. An id the session does
  /// not have is ignored.
  Future<void> select(String groupId) async {
    final collection = await _collection();
    if (collection == null || _disposed) return;
    if (!collection.groups.any((g) => g.id == groupId)) return;
    if (collection.selectedGroupId != groupId) {
      collection.selectedGroupId = groupId;
      await _save(collection);
    }
    _publish(collection, state.status);
    await _startRunIfNeeded(collection);
  }

  /// Publishes the session as it is saved now, without grouping: a story run
  /// finished and changed a group's story (AC-16).
  Future<void> reload() async {
    final collection = await _collection();
    if (collection == null || _disposed) return;
    _publish(collection, state.status);
  }

  Future<void> _ensureGrouped() async {
    final collection = await _collection();
    if (collection == null || _disposed) return;
    final runs = await _runsInProgress(collection.collectionId);

    var status = const GroupingIdle() as GroupingStatus;
    // A word edited while the Worker was thinking means the split no longer
    // fits: plan again with the new words (a few rounds at most).
    for (var round = 0; round < 3; round++) {
      final plan = planGrouping(collection, runs);
      if (plan is GroupingLocal) {
        _apply(collection, plan.groups);
      } else if (plan is GroupingAsk) {
        _publish(collection, const GroupingInProgress(), hideGroups: true);
        final keyBefore = groupedWordsKey(collection);
        final SplitResult result;
        try {
          final split = await ref.read(storyApiServiceProvider).group(plan.words, plan.keep);
          if (_disposed) return;
          if (groupedWordsKey(collection) != keyBefore) continue;
          result = applySplit(collection, split, runs);
        } catch (_) {
          status = const GroupingFailed();
          break;
        }
        if (result is SplitOk) {
          _apply(collection, result.groups);
        } else {
          status = const GroupingFailed();
        }
      }
      break;
    }
    if (_disposed) return;
    if (status is GroupingFailed) {
      _publish(collection, status, hideGroups: true);
      return;
    }

    // The remembered group may be gone: keep the effective one (AC-01).
    collection.selectedGroupId = selectedGroupIdOf(collection);
    await _save(collection);
    if (_disposed) return;
    _publish(collection, status);
    await _startRunIfNeeded(collection);
  }

  void _apply(WordCollection collection, List<WordGroup> groups) {
    collection.groups = groups;
    collection.groupedWordsKey = groupedWordsKey(collection);
  }

  /// The learn words that sit in no group.
  int _waiting(WordCollection collection) {
    final held = {for (final g in collection.groups) ...g.rowIds};
    return wordsToLearn(collection).where((w) => !held.contains(w.rowId)).length;
  }

  void _publish(WordCollection collection, GroupingStatus status, {bool hideGroups = false}) {
    if (_disposed) return;
    final waiting = status is GroupingIdle ? _waiting(collection) : 0;
    state = WordGroupsState(
      status: waiting > 0 ? GroupingWaiting(waiting) : status,
      groups: hideGroups ? const [] : [for (final g in collection.groups) g.copy()],
      selectedGroupId: hideGroups ? null : selectedGroupIdOf(collection),
    );
  }

  Future<void> _startRunIfNeeded(WordCollection collection) async {
    if (_disposed) return;
    final id = selectedGroupIdOf(collection);
    final group = collection.groups.where((g) => g.id == id).firstOrNull;
    if (group == null || group.storyRunId != null) return;
    // A dialogue group draws only on Start (get-words-from-subtitles-improvment
    // AC-24).
    if (group.dialogueId != null) return;
    if ((await _runsInProgress(collection.collectionId)).contains(group.id)) return;
    try {
      await ref.read(storyRunStartHookProvider)(collection.collectionId, group);
    } catch (_) {
      // starting a run is the tracker's business; it reports its own failures
    }
  }

  /// The current session's live object (held by the Words screen's notifier,
  /// which may have words not yet written), or a History session from the store.
  Future<WordCollection?> _collection() async {
    final wanted = collectionId;
    if (wanted == null) return ref.read(wordInputNotifierProvider.future);
    final current = ref.read(wordInputNotifierProvider).valueOrNull;
    if (current != null && current.collectionId == wanted) return current;
    final store = await ref.read(collectionStoreProvider.future);
    return store.byId(wanted);
  }

  /// Saves without stamping the edit times: grouping is not an edit. Only the
  /// grouping fields are written, into the stored record (ADR-0006), so a
  /// change made by anyone else while the Worker was splitting stays.
  Future<void> _save(WordCollection collection) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.update(collection.collectionId, (stored) {
      stored
        ..groups = [for (final g in collection.groups) g.copy()]
        ..selectedGroupId = collection.selectedGroupId
        ..groupedWordsKey = collection.groupedWordsKey;
    });
  }

  /// Ids of the groups whose story run is going; they count as groups with a
  /// story (AC-05).
  Future<Set<String>> _runsInProgress(String collectionId) async {
    try {
      final runs = await (await ref.read(storyRunStoreProvider.future)).uncollected();
      return {
        for (final r in runs)
          if (r.collectionId == collectionId && r.outcome == 'running') r.groupId,
      };
    } catch (_) {
      return const {};
    }
  }
}
