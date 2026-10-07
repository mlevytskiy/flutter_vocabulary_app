import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/word_input/word_input_notifier.dart';
import '../models/session.dart';
import '../models/word_group.dart';
import '../providers.dart';
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
}

/// Asks the story run tracker to start a run for a group that has neither a
/// story nor a run (AC-06). A no-op until `StoryRunTracker` (T15) replaces it.
typedef StoryRunStartHook = Future<void> Function(String sessionId, WordGroup group);

final storyRunStartHookProvider = Provider<StoryRunStartHook>((ref) => (sessionId, group) async {});

/// The groups of one session and the learner's selection among them. A null
/// [sessionId] is the current session; an id is a History session, which is
/// read and saved on its own and never becomes current (AC-11). Lives in
/// `lib/core/story/` so the Words screen and the learn page share it.
@Riverpod(keepAlive: true)
class WordGroupsNotifier extends _$WordGroupsNotifier {
  Future<void>? _inFlight;
  bool _disposed = false;

  @override
  WordGroupsState build(String? sessionId) {
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
    final session = await _session();
    if (session == null || _disposed) return;
    if (!session.groups.any((g) => g.id == groupId)) return;
    if (session.selectedGroupId != groupId) {
      session.selectedGroupId = groupId;
      await _save(session);
    }
    _publish(session, state.status);
    await _startRunIfNeeded(session);
  }

  Future<void> _ensureGrouped() async {
    final session = await _session();
    if (session == null || _disposed) return;
    final runs = await _runsInProgress(session.sessionId);

    var status = const GroupingIdle() as GroupingStatus;
    // A word edited while the Worker was thinking means the split no longer
    // fits: plan again with the new words (a few rounds at most).
    for (var round = 0; round < 3; round++) {
      final plan = planGrouping(session, runs);
      if (plan is GroupingLocal) {
        _apply(session, plan.groups);
      } else if (plan is GroupingAsk) {
        _publish(session, const GroupingInProgress(), hideGroups: true);
        final keyBefore = groupedWordsKey(session);
        final SplitResult result;
        try {
          final split = await ref.read(storyApiServiceProvider).group(plan.words, plan.keep);
          if (_disposed) return;
          if (groupedWordsKey(session) != keyBefore) continue;
          result = applySplit(session, split, runs);
        } catch (_) {
          status = const GroupingFailed();
          break;
        }
        if (result is SplitOk) {
          _apply(session, result.groups);
        } else {
          status = const GroupingFailed();
        }
      }
      break;
    }
    if (_disposed) return;
    if (status is GroupingFailed) {
      _publish(session, status, hideGroups: true);
      return;
    }

    // The remembered group may be gone: keep the effective one (AC-01).
    session.selectedGroupId = selectedGroupIdOf(session);
    await _save(session);
    if (_disposed) return;
    _publish(session, status);
    await _startRunIfNeeded(session);
  }

  void _apply(Session session, List<WordGroup> groups) {
    session.groups = groups;
    session.groupedWordsKey = groupedWordsKey(session);
  }

  /// The learn words that sit in no group.
  int _waiting(Session session) {
    final held = {for (final g in session.groups) ...g.rowIds};
    return wordsToLearn(session).where((w) => !held.contains(w.rowId)).length;
  }

  void _publish(Session session, GroupingStatus status, {bool hideGroups = false}) {
    if (_disposed) return;
    final waiting = status is GroupingIdle ? _waiting(session) : 0;
    state = WordGroupsState(
      status: waiting > 0 ? GroupingWaiting(waiting) : status,
      groups: hideGroups ? const [] : [for (final g in session.groups) g.copy()],
      selectedGroupId: hideGroups ? null : selectedGroupIdOf(session),
    );
  }

  Future<void> _startRunIfNeeded(Session session) async {
    if (_disposed) return;
    final id = selectedGroupIdOf(session);
    final group = session.groups.where((g) => g.id == id).firstOrNull;
    if (group == null || group.storyRunId != null) return;
    if ((await _runsInProgress(session.sessionId)).contains(group.id)) return;
    try {
      await ref.read(storyRunStartHookProvider)(session.sessionId, group);
    } catch (_) {
      // starting a run is the tracker's business; it reports its own failures
    }
  }

  /// The current session's live object (held by the Words screen's notifier,
  /// which may have words not yet written), or a History session from the store.
  Future<Session?> _session() async {
    final wanted = sessionId;
    if (wanted == null) return ref.read(wordInputNotifierProvider.future);
    final current = ref.read(wordInputNotifierProvider).valueOrNull;
    if (current != null && current.sessionId == wanted) return current;
    final store = await ref.read(sessionStoreProvider.future);
    return store.byId(wanted);
  }

  /// Saves without stamping the edit times: grouping is not an edit.
  Future<void> _save(Session session) async {
    final store = await ref.read(sessionStoreProvider.future);
    await store.put(session);
  }

  /// Ids of the groups whose story run is going; they count as groups with a
  /// story (AC-05).
  Future<Set<String>> _runsInProgress(String sessionId) async {
    try {
      final runs = await (await ref.read(storyRunStoreProvider.future)).uncollected();
      return {
        for (final r in runs)
          if (r.sessionId == sessionId && r.outcome == 'running') r.groupId,
      };
    } catch (_) {
      return const {};
    }
  }
}
