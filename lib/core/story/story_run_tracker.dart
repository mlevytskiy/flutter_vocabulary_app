import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/word_input/word_input_notifier.dart';
import '../models/offered_ai.dart';
import '../models/session.dart';
import '../models/story_run.dart';
import '../models/word_group.dart';
import '../providers.dart';
import '../services/source_photo_store.dart' show uuidV4;
import '../services/story_api_service.dart';
import 'word_grouping.dart';
import 'word_groups_notifier.dart';

part 'story_run_tracker.g.dart';

/// How often the tracker asks the Worker for the runs it still follows
/// (ADR-0002: one status call every 5 s, only while a story screen is open).
final storyPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 5));

/// Why a run, a "Try again" or a "Draw again" did not go ahead (AC-13, AC-19).
class StoryStartRefusal {
  /// The Worker's refusal; [StoryRefusal.unavailable] also stands for a start
  /// that could not reach the Worker at all.
  final StoryRefusal reason;

  /// The name of the AI that is no longer offered, for [StoryRefusal.notOffered].
  final String? aiName;
  const StoryStartRefusal(this.reason, {this.aiName});
}

class StoryTrackerState {
  /// The latest refusal per group id; cleared when a run for the group starts.
  final Map<String, StoryStartRefusal> refusals;
  const StoryTrackerState({this.refusals = const {}});
}

/// A screen's hold on the tracker: while any is held, the tracker polls.
class StoryFollow {
  final void Function() _onRelease;
  bool _released = false;
  StoryFollow._(this._onRelease);

  /// Lets go; a second call does nothing.
  void release() {
    if (_released) return;
    _released = true;
    _onRelease();
  }
}

/// Starts story runs, follows them on the Worker and collects their results to
/// the phone (mnemonic-story ADR-0002, sad §6 S-02, S-04, S-05).
///
/// A run is saved before it is started, so a closed app finds it again and
/// collects it without starting it twice (AC-10). Nothing here throws.
@Riverpod(keepAlive: true)
class StoryRunTracker extends _$StoryRunTracker {
  /// A run the Worker does not report after this long never started there.
  static const _unknownAfter = Duration(minutes: 2);
  static const _maxBackoff = 12;
  static const _statusBatch = 50;

  int _followers = 0;
  Timer? _timer;
  bool _pending = false;
  bool _disposed = false;
  Future<void> _queue = Future.value();

  /// Pre-redo signatures of steps the Worker may still report as they were.
  final Map<String, String> _stale = {};

  /// Multiplier of the poll interval: doubles on each "too many requests".
  @visibleForTesting
  int backoff = 1;

  /// The one poll made when the tracker comes up (app start, AC-10).
  @visibleForTesting
  Future<void> startup = Future.value();

  @override
  StoryTrackerState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });
    startup = Future(poll);
    return const StoryTrackerState();
  }

  // --- starting -----------------------------------------------------------

  /// Starts a run for [group] of [sessionId] with the AI choice as it stands,
  /// and returns its id; null when none started. Without [replacing] (the
  /// automatic start, AC-06) nothing starts for a group that has a story, a run
  /// going, or a failed run waiting for the learner's "Try again" (AC-07, AC-08).
  /// [replacing] is "Try again" and "Make a new story" (AC-16): it starts
  /// unless a run for the group is going.
  Future<String?> startFor(String sessionId, WordGroup group, {bool replacing = false}) async {
    try {
      return await _startFor(sessionId, group, replacing);
    } catch (e) {
      debugPrint('VOCAB: starting a story run failed: $e');
      return null;
    }
  }

  Future<String?> _startFor(String sessionId, WordGroup group, bool replacing) async {
    final runStore = await ref.read(storyRunStoreProvider.future);
    final ofGroup = [
      for (final r in await runStore.newestFirst())
        if (r.sessionId == sessionId && r.groupId == group.id) r,
    ];
    if (ofGroup.any((r) => r.outcome == 'running')) return null;
    if (!replacing) {
      if (group.storyRunId != null) return null;
      final latest = ofGroup.firstOrNull;
      if (latest != null && latest.outcome == 'failed' && latest.steps.isNotEmpty) return null;
    }

    final session = await _session(sessionId);
    if (session == null || _disposed) return null;
    final words = [
      for (final w in groupWords(session, group))
        if (w.word.trim().isNotEmpty) w.word.trim(),
    ];
    if (words.isEmpty) return null;

    final offered = await ref.read(offeredAisProvider.future);
    final choice = await _resolvedChoice(offered);
    final run = StoryRun()
      ..runId = uuidV4()
      ..sessionId = sessionId
      ..groupId = group.id
      ..groupName = group.name
      ..words = words
      ..startedAt = DateTime.now()
      ..models = [choice.story, choice.prompt, choice.picture];
    await runStore.put(run);
    _clearRefusal(group.id);

    final StoryActionResult result;
    try {
      result = await ref.read(storyApiServiceProvider).startRun(
            runId: run.runId,
            words: words,
            storyModel: choice.story,
            promptModel: choice.prompt,
            pictureModel: choice.picture,
          );
    } catch (_) {
      await _notStarted(run, const StoryStartRefusal(StoryRefusal.unavailable));
      return null;
    }
    if (result is StoryRefused) {
      await _notStarted(run, await _refusal(result, run.models, offered));
      return null;
    }
    _wake();
    return run.runId;
  }

  /// "Try again" after the picture prompt failed: redoes only that step of the
  /// same run, from the same story, taking no allowance (AC-08b).
  Future<StoryActionResult> redoPrompt(String runId) async {
    final runStore = await ref.read(storyRunStoreProvider.future);
    final run = await runStore.byId(runId);
    if (run == null) return const StoryRefused(StoryRefusal.unknownRun);
    final result = await _redo(run, 'prompt', null);
    if (result is StoryStarted) {
      final steps = [...run.steps];
      for (var i = 0; i < steps.length; i++) {
        if (steps[i].role == 'prompt') {
          _stale['$runId:prompt:${steps[i].attempt}'] = _signature(steps[i]);
          steps[i] = _copyOf(steps[i])..outcome = 'running';
        }
      }
      run
        ..steps = steps
        ..outcome = 'running'
        ..collected = false;
      await runStore.put(run);
      _wake();
    }
    return result;
  }

  /// "Draw again" after the picture failed: a new picture attempt on the same
  /// run, with the picture maker chosen now; the failed attempt stays (AC-09).
  Future<StoryActionResult> drawAgain(String runId) async {
    final runStore = await ref.read(storyRunStoreProvider.future);
    final run = await runStore.byId(runId);
    if (run == null) return const StoryRefused(StoryRefusal.unknownRun);
    final offered = await ref.read(offeredAisProvider.future);
    final pictureModel = (await _resolvedChoice(offered)).picture;
    final result = await _redo(run, 'picture', pictureModel);
    if (result is StoryStarted) {
      final last = run.steps.where((s) => s.role == 'picture').map((s) => s.attempt).fold(0, (a, b) => a > b ? a : b);
      run
        ..steps = [
          ...run.steps,
          StoryStep()
            ..role = 'picture'
            ..attempt = result.attempt ?? last + 1
            ..modelId = pictureModel
            ..modelName = offered.byId(pictureModel)?.name ?? pictureModel,
        ]
        ..outcome = 'running'
        ..collected = false;
      await runStore.put(run);
      _wake();
    }
    return result;
  }

  Future<StoryActionResult> _redo(StoryRun run, String step, String? pictureModel) async {
    final StoryActionResult result;
    try {
      result = await ref.read(storyApiServiceProvider).redo(runId: run.runId, step: step, pictureModel: pictureModel);
    } catch (_) {
      _refuse(run.groupId, const StoryStartRefusal(StoryRefusal.unavailable));
      return const StoryRefused(StoryRefusal.unavailable);
    }
    if (result is StoryRefused) {
      _refuse(run.groupId, await _refusal(result, run.models, await ref.read(offeredAisProvider.future)));
    } else {
      _clearRefusal(run.groupId);
    }
    return result;
  }

  // --- following ----------------------------------------------------------

  /// Holds the tracker polling until the returned handle is released. A story
  /// screen takes one while it is open.
  StoryFollow follow() {
    _followers++;
    if (_followers == 1) unawaited(poll().whenComplete(_schedule));
    return StoryFollow._(() {
      _followers--;
      if (_followers <= 0) {
        _followers = 0;
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void _wake() {
    _pending = true;
    if (_followers > 0 && _timer == null) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _followers == 0 || !_pending) return;
    _timer = Timer(ref.read(storyPollIntervalProvider) * backoff, () {
      _timer = null;
      poll().whenComplete(_schedule);
    });
  }

  /// One status call for every run not yet collected, then records what came
  /// back. Calls queue up rather than overlap. Never throws.
  Future<void> poll() {
    final next = _queue.then((_) => _poll()).catchError((Object e) {
      debugPrint('VOCAB: following story runs failed: $e');
    });
    _queue = next;
    return next;
  }

  Future<void> _poll() async {
    if (_disposed) return;
    final runStore = await ref.read(storyRunStoreProvider.future);
    final runs = (await runStore.uncollected()).take(_statusBatch).toList();
    _pending = runs.isNotEmpty;
    if (runs.isEmpty) return;

    final List<RunStatus> statuses;
    try {
      statuses = await ref.read(storyApiServiceProvider).status([for (final r in runs) r.runId]);
      backoff = 1;
    } on StoryApiException catch (e) {
      if (e.error == StoryApiError.rateLimited) {
        backoff = backoff * 2 > _maxBackoff ? _maxBackoff : backoff * 2;
      }
      return;
    }
    final byId = {for (final s in statuses) s.runId: s};
    final offered = await ref.read(offeredAisProvider.future);
    for (final listed in runs) {
      if (_disposed) return;
      final run = await runStore.byId(listed.runId); // may have changed meanwhile
      if (run == null || run.collected) continue;
      final status = byId[run.runId];
      if (status == null) {
        if (DateTime.now().difference(run.startedAt) > _unknownAfter) {
          run
            ..outcome = 'failed'
            ..collected = true;
          await runStore.put(run);
        }
        continue;
      }
      await _record(run, status, offered);
    }
    _pending = (await runStore.uncollected()).isNotEmpty;
  }

  /// Takes the Worker's steps into [run]; when the last picture is done, copies
  /// it to the phone and makes the run the group's story (AC-16).
  Future<void> _record(StoryRun run, RunStatus status, OfferedAiList offered) async {
    final runStore = await ref.read(storyRunStoreProvider.future);
    final merged = <String, StoryStep>{for (final s in run.steps) _key(s.role, s.attempt): s};
    for (final w in status.steps) {
      final key = _key(w.role, w.attempt);
      final stale = _stale['${run.runId}:${w.role}:${w.attempt}'];
      final old = merged[key];
      if (stale != null && _signatureOfWorker(w) == stale) continue; // the redo has not started yet
      _stale.remove('${run.runId}:${w.role}:${w.attempt}');
      merged[key] = StoryStep()
        ..role = w.role
        ..attempt = w.attempt
        ..modelId = w.modelId
        ..modelName = offered.byId(w.modelId)?.name ?? w.modelId
        ..outcome = w.outcome
        ..text = w.text
        ..picturePath = old?.picturePath
        ..missedWords = [...w.missedWords]
        ..priceUsd = w.priceUsd
        ..priceEstimated = w.priceEstimated
        ..ms = w.ms;
    }
    final steps = merged.values.toList()
      ..sort((a, b) {
        final byRole = _order(a.role).compareTo(_order(b.role));
        return byRole != 0 ? byRole : a.attempt.compareTo(b.attempt);
      });
    run.steps = steps;
    run.outcome = _outcomeOf(steps);

    if (run.outcome == 'done') {
      final picture = steps.where((s) => s.role == 'picture').last;
      if (picture.picturePath == null && !await _collectPicture(run, picture)) {
        if (_disposed) return;
        if (run.outcome == 'running') {
          // Could not reach the Worker for the picture: try again next poll.
          await runStore.put(run);
          return;
        }
      }
    }
    if (run.outcome != 'running') run.collected = true;
    await runStore.put(run);
    if (run.outcome == 'done') await _makeGroupStory(run);
  }

  /// Fetches, compresses and keeps the picture of [picture]'s attempt. Returns
  /// true when it is on the phone. Otherwise leaves [run] running (the Worker
  /// could not be reached) or failed (the picture is gone or cannot be kept).
  Future<bool> _collectPicture(StoryRun run, StoryStep picture) async {
    final Uint8List? bytes;
    try {
      bytes = await ref.read(storyApiServiceProvider).picture(run.runId, picture.attempt);
    } catch (_) {
      run.outcome = 'running';
      return false;
    }
    final path = bytes == null
        ? null
        : await ref.read(storyPictureStoreProvider).write(run.runId, picture.attempt, bytes);
    if (path == null) {
      // Already collected elsewhere and gone, or too big to keep: draw again.
      picture.outcome = 'failed';
      run.outcome = 'failed';
      return false;
    }
    picture.picturePath = path;
    return true;
  }

  Future<void> _makeGroupStory(StoryRun run) async {
    final session = await _session(run.sessionId);
    if (session == null) return;
    final group = session.groups.where((g) => g.id == run.groupId).firstOrNull;
    if (group == null) return;
    group
      ..storyRunId = run.runId
      ..storyWords = [...run.words];
    await (await ref.read(sessionStoreProvider.future)).put(session);
    final current = ref.read(wordInputNotifierProvider).valueOrNull?.sessionId == run.sessionId;
    final groups = wordGroupsNotifierProvider(current ? null : run.sessionId);
    if (ref.exists(groups)) await ref.read(groups.notifier).reload();
  }

  // --- helpers ------------------------------------------------------------

  /// The saved choice checked against the offered list: a withdrawn AI falls
  /// back to its default, so no run starts with one (AC-13).
  Future<AiChoice> _resolvedChoice(OfferedAiList offered) async {
    await ref.read(aiChoiceProvider.notifier).loaded;
    return resolveAiChoice(ref.read(aiChoiceProvider), offered).choice;
  }

  /// Turns the Worker's [refused] into the recorded refusal. A "not offered"
  /// puts that step back on its default AI (AC-13).
  Future<StoryStartRefusal> _refusal(StoryRefused refused, List<String> models, OfferedAiList offered) async {
    if (refused.reason != StoryRefusal.notOffered) return StoryStartRefusal(refused.reason);
    final model = refused.model;
    final index = model == null ? -1 : models.indexOf(model);
    if (index >= 0) {
      final role = AiRole.values[index];
      final fallback = offered.byId(offered.defaults.of(role));
      if (fallback != null) await ref.read(aiChoiceProvider.notifier).set(role, fallback);
    }
    return StoryStartRefusal(refused.reason, aiName: model == null ? null : offered.byId(model)?.name ?? model);
  }

  /// A run that never started: kept in the story runs, but not followed.
  Future<void> _notStarted(StoryRun run, StoryStartRefusal refusal) async {
    run
      ..outcome = 'failed'
      ..collected = true;
    await (await ref.read(storyRunStoreProvider.future)).put(run);
    _refuse(run.groupId, refusal);
  }

  void _refuse(String groupId, StoryStartRefusal refusal) {
    if (_disposed) return;
    state = StoryTrackerState(refusals: {...state.refusals, groupId: refusal});
  }

  void _clearRefusal(String groupId) {
    if (_disposed || !state.refusals.containsKey(groupId)) return;
    state = StoryTrackerState(refusals: {...state.refusals}..remove(groupId));
  }

  /// The current session's live object, or a History session from the store.
  Future<Session?> _session(String sessionId) async {
    final current = await ref.read(wordInputNotifierProvider.future);
    if (current.sessionId == sessionId) return current;
    return (await ref.read(sessionStoreProvider.future)).byId(sessionId);
  }

  static String _key(String role, int attempt) => '$role:$attempt';
  static int _order(String role) => const {'story': 0, 'prompt': 1, 'picture': 2}[role] ?? 3;

  static StoryStep _copyOf(StoryStep s) => StoryStep()
    ..role = s.role
    ..attempt = s.attempt
    ..modelId = s.modelId
    ..modelName = s.modelName
    ..outcome = s.outcome
    ..text = s.text
    ..picturePath = s.picturePath
    ..missedWords = [...s.missedWords]
    ..priceUsd = s.priceUsd
    ..priceEstimated = s.priceEstimated
    ..ms = s.ms;

  static String _signature(StoryStep s) => '${s.outcome}|${s.priceUsd}|${s.ms}|${s.text}';
  static String _signatureOfWorker(StepStatus s) => '${s.outcome}|${s.priceUsd}|${s.ms}|${s.text}';

  /// Where the run stands, from its story, its prompt and its latest picture.
  static String _outcomeOf(List<StoryStep> steps) {
    StoryStep? last(String role) => steps.where((s) => s.role == role).lastOrNull;
    for (final role in const ['story', 'prompt', 'picture']) {
      final s = last(role);
      if (s == null || s.outcome == 'running') return 'running';
      if (s.outcome == 'failed') return 'failed';
    }
    return 'done';
  }
}
