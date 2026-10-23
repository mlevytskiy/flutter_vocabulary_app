import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_collection.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../../../core/story/word_grouping.dart' show wordsToLearn;
import '../../words/words_notifier.dart';
import '../entry/learn_presets.dart';
import '../kit/exercise_random.dart';
import 'exercise_page.dart';
import 'ladder_queue.dart';
import 'leitner.dart';
import 'page_input.dart';
import 'page_registry.dart';
import 'session_result.dart';
import 'session_words.dart';

part 'learning_session_notifier.g.dart';

/// Where a learning session stands (SCR-03).
enum SessionStatus {
  /// Picking words and building the pages of the step about to play.
  loading,

  /// A page is shown ([LearningSessionState.page]).
  playing,

  /// No page could be built because AI data failed: the error line + Retry.
  error,

  /// Every word passed a Use page; [LearningSessionState.outcomes] is set.
  finished,

  /// No exercise has a page for these words.
  notEnough,
}

/// What the session screen shows (learn-redesign ADR-0004, SCR-03).
class LearningSessionState {
  const LearningSessionState({
    this.status = SessionStatus.loading,
    this.pick,
    this.queue,
    this.page,
    this.answer,
    this.pageIndex = 0,
    this.verdict,
    this.pageNumber = 0,
    this.pageTotal = 0,
    this.step = 1,
    this.stepProgress = 0,
    this.loadFailed = false,
    this.outcomes = const {},
  });

  final SessionStatus status;

  /// The session's words (null until picked).
  final SessionPick? pick;

  /// The word ladder (null until picked).
  final LadderQueue? queue;

  /// The page shown while [status] is [SessionStatus.playing].
  final ExercisePage? page;

  /// The current page's answer channel, new for every page.
  final PageAnswer? answer;

  /// Counts the pages shown; the screen keys each page body with it so no
  /// body state carries over to the next page.
  final int pageIndex;

  /// Set once the current page was answered, until Continue.
  final PageVerdict? verdict;

  /// "page N of M" (AC-08): N and the estimated M.
  final int pageNumber;
  final int pageTotal;

  /// The step (1–3) of the current page's rung and how far the words have
  /// got past it (0–1).
  final int step;
  final double stepProgress;

  /// Some exercise's AI data could not be loaded: one error line with Retry
  /// while the other pages play (AC-11).
  final bool loadFailed;

  /// Each word's outcome once [status] is [SessionStatus.finished], keyed by
  /// the same [WordPair] instances as [SessionPick.words] (for `applySession`).
  final Map<WordPair, WordOutcome> outcomes;
}

/// One learning session of a collection (learn-redesign ADR-0004; AC-02,
/// AC-08, AC-09, AC-11, AC-16). [collectionId] null is the current
/// collection, as in `exerciseWords`.
///
/// [start] picks the words (`pickSessionWords`), draws min(3, switched on)
/// exercise types per step, builds step 1's pages and shows the first one;
/// steps 2 and 3 load in the background and are awaited when the first word
/// reaches them. Each (word, rung) the [LadderQueue] asks for maps to an
/// unused page of that step holding the word, rotating exercise types. AI
/// data is fetched in batches of at most [batchSize] words. Leaving a
/// session changes no box (AC-16); only finishing writes them, once.
@riverpod
class LearningSession extends _$LearningSession {
  /// The most words one page-source call gets (sad §11).
  static const batchSize = 19;

  /// The most exercise types one step draws (AC-08).
  static const typesPerStep = 3;

  /// Tried when no drawn exercise has a page (SCR-03 empty state).
  static const _fallbackIds = ['remember-or-not', 'pick-the-answer'];

  late Random _random;
  late Map<String, PageSource> _sources;
  late WordCollection _collection;
  late List<WordPair> _others;
  late Map<String, WordPair> _byRow;
  SessionPick? _pick;
  LadderQueue? _queue;
  bool _split = false;
  bool _disposed = false;

  final _drawn = <int, List<String>>{};
  final _pages = <int, List<ExercisePage>>{1: [], 2: [], 3: []};
  final _loads = <int, Future<void>>{};
  final _loadedSteps = <int>{};
  final _failed = <String>{};
  final _used = <ExercisePage>{};
  final _lastShown = <String, int>{};
  final _shownRows = <String>{};
  int _pageIndex = 0;
  int _skipped = 0;
  int _pageNumber = 0;
  int _pageTotal = 0;
  int _step = 1;
  double _stepProgress = 0;
  ExercisePage? _page;
  PageAnswer? _answer;
  PageVerdict? _verdict;
  Map<WordPair, WordOutcome> _outcomes = const {};

  @override
  LearningSessionState build(String? collectionId) {
    ref.onDispose(() => _disposed = true);
    return const LearningSessionState();
  }

  /// Every drawn source's first load, for tests.
  @visibleForTesting
  Future<void> get pagesLoaded => Future.wait(_loads.values);

  /// Starts the session (AC-02): [split] as ticked on the Learn sheet,
  /// [rowIds] for exactly those rows ("Practise N shaky words").
  ///
  /// [skipGroup] is "Next group": the group just played, left out of the
  /// picker's due / new rules (AC-12).
  Future<void> start({required bool split, List<String>? rowIds, int? skipGroup}) async {
    _publish(SessionStatus.loading);
    final collection = await _readOnce(collectionId == null
        ? wordsNotifierProvider.future
        : collectionByIdProvider(collectionId!).future);
    if (_disposed) return;
    if (collection == null) return _publish(SessionStatus.notEnough);
    _collection = collection;
    _split = split;

    final settingsNotifier = ref.read(learnSettingsNotifierProvider.notifier);
    await settingsNotifier.loaded;
    final lastNotifier = ref.read(learnLastGroupNotifierProvider(collection.collectionId).notifier);
    await lastNotifier.loaded;
    if (_disposed) return;
    final settings = ref.read(learnSettingsNotifierProvider);
    final pick = pickSessionWords(
      collection,
      split: split,
      wordsPerSession: settings.wordsPerSession.count,
      lastGroup: ref.read(learnLastGroupNotifierProvider(collection.collectionId)),
      rowIds: rowIds,
      skipGroup: skipGroup,
      now: DateTime.now(),
    );
    if (pick.words.isEmpty) return _publish(SessionStatus.notEnough);
    _pick = pick;
    _byRow = {for (final w in pick.words) w.rowId: w};
    _others = [for (final w in wordsToLearn(collection)) if (!_byRow.containsKey(w.rowId)) w];
    _random = ref.read(exerciseRandomProvider);
    _sources = ref.read(pageSourcesProvider);

    // min(3, switched on) types per step; story and dialogues are never
    // page exercises (AC-08).
    for (final step in [1, 2, 3]) {
      final on = [
        for (final id in pageExerciseIds)
          if (settings.enabled.contains(id) && _sources.containsKey(id) && stepOf(id) == step) id
      ]..shuffle(_random);
      _drawn[step] = on.take(min(typesPerStep, on.length)).toList();
    }
    _queue = LadderQueue([for (final w in pick.words) w.rowId], due: pick.dueRowIds, random: _random);

    // Step 1 up front; steps 2 and 3 start now and are awaited when the
    // first word reaches them.
    for (final step in [1, 2, 3]) {
      _loads[step] = _loadStep(step);
    }
    await _loads[1];
    if (_disposed) return;
    if (_pages[1]!.isEmpty) {
      await pagesLoaded;
      if (_disposed) return;
    }
    if (_pageCount == 0 && _failed.isEmpty) {
      final fallback = _fallbackIds.where((id) => _sources.containsKey(id) && !_drawn.values.any((d) => d.contains(id)));
      await Future.wait(fallback.map(_loadSource));
      if (_disposed) return;
    }
    if (_pageCount == 0) {
      return _publish(_failed.isEmpty ? SessionStatus.notEnough : SessionStatus.error);
    }
    await _advance();
  }

  /// The current page was answered: [results] holds right/wrong by row id
  /// (a board page has several). Records each word on the ladder and sets
  /// the verdict (AC-09, AC-10).
  void answer(Map<String, bool> results) {
    final page = _page;
    final queue = _queue;
    if (page == null || queue == null || _verdict != null) return;
    final rights = <String, bool>{
      for (final id in page.rowIds)
        if (_byRow.containsKey(id) && !queue.passed(id)) id: results[id] ?? false,
    };
    rights.forEach(queue.record);
    final right = rights.values.every((r) => r);
    if (page.rowIds.length > 1) {
      final count = rights.values.where((r) => r).length;
      _verdict = PageVerdict(right: right, word: '$count of ${rights.length} right', translation: '');
    } else {
      final w = _byRow[page.rowIds.first]!;
      _verdict = PageVerdict(
        right: right,
        word: w.word.trim(),
        translation: w.translation.trim().isNotEmpty ? w.translation.trim() : w.definition.trim(),
      );
    }
    _publish(SessionStatus.playing);
  }

  /// Continue: the next page, or the end when every word has passed.
  Future<void> next() async {
    if (_verdict == null) return;
    _verdict = null;
    await _advance();
  }

  /// Loads the sources that failed again (AC-11).
  Future<void> retry() async {
    if (_failed.isEmpty) return;
    final wasError = state.status == SessionStatus.error;
    if (wasError) _publish(SessionStatus.loading);
    await Future.wait([..._failed].map(_loadSource));
    if (_disposed) return;
    if (wasError) {
      if (_pageCount == 0) return _publish(SessionStatus.error);
      return _advance();
    }
    _publish(state.status);
  }

  int get _pageCount => _pages.values.fold(0, (sum, p) => sum + p.length);

  Future<T> _readOnce<T>(ProviderListenable<Future<T>> provider) async {
    final sub = ref.listen(provider, (_, __) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }

  Future<void> _loadStep(int step) async {
    await Future.wait(_drawn[step]!.map(_loadSource));
    _loadedSteps.add(step);
  }

  /// Runs one exercise's page source over the session's words in batches of
  /// at most [batchSize]. A [LearnApiException] leaves the exercise without
  /// pages (no half-filled page) and turns the error line on (AC-11).
  Future<void> _loadSource(String id) async {
    final pick = _pick!;
    final words = pick.words;
    final count = (words.length / batchSize).ceil();
    final batches = [
      for (var i = 0; i < count; i++) words.sublist(i * words.length ~/ count, (i + 1) * words.length ~/ count),
    ];
    try {
      final results = await Future.wait([
        for (final batch in batches)
          _sources[id]!(PageInput(
            words: batch,
            others: [..._others, for (final w in words) if (!batch.contains(w)) w],
            dialogues: _collection.dialogues,
            api: ref.read(learnApiServiceProvider),
            random: _random,
          )),
      ]);
      if (_disposed) return;
      _pages[stepOf(id)]!.addAll(results.expand((p) => p));
      _failed.remove(id);
    } on LearnApiException {
      _failed.add(id);
    }
  }

  /// Shows the page for the queue's next (word, rung), waiting for that
  /// step's pages first; a rung no page can serve counts as passed.
  Future<void> _advance() async {
    final queue = _queue!;
    while (true) {
      final next = queue.next();
      if (next == null) return await _finish();
      final step = next.rung.step;
      if (!_loadedSteps.contains(step)) {
        _page = null;
        _publish(SessionStatus.loading);
        await _loads[step];
        if (_disposed) return;
      }
      final page = _choose(next.rowId, next.rung);
      if (page == null) {
        queue.record(next.rowId, true);
        _skipped++;
        continue;
      }
      _show(page, next.rung);
      return;
    }
  }

  /// An unused page of [rung]'s step holding [rowId], rotating exercise
  /// types; a board page only while all its words stand on [rung]. Else a
  /// used one, else a single-word page of another loaded step.
  ExercisePage? _choose(String rowId, Rung rung) {
    final queue = _queue!;
    bool onRung(String id) => _byRow.containsKey(id) && !queue.passed(id) && queue.rungOf(id) == rung;
    bool fits(ExercisePage p) => p.rowIds.contains(rowId) && (p.rowIds.length == 1 || p.rowIds.every(onRung));
    bool single(ExercisePage p) => p.rowIds.length == 1 && p.rowIds.first == rowId;
    final own = _pages[rung.step]!;
    final other = [
      for (final s in [1, 2, 3])
        if (s != rung.step && _loadedSteps.contains(s)) ..._pages[s]!
    ];
    for (final candidates in [
      own.where((p) => fits(p) && !_used.contains(p)),
      own.where(fits),
      other.where((p) => single(p) && !_used.contains(p)),
      other.where(single),
    ]) {
      ExercisePage? best;
      for (final p in candidates) {
        if (best == null || (_lastShown[p.exerciseId] ?? -1) < (_lastShown[best.exerciseId] ?? -1)) best = p;
      }
      if (best != null) return best;
    }
    return null;
  }

  void _show(ExercisePage page, Rung rung) {
    final queue = _queue!;
    _pageIndex++;
    _page = page;
    _answer = PageAnswer();
    _verdict = null;
    _used.add(page);
    _lastShown[page.exerciseId] = _pageIndex;
    _shownRows.addAll(page.rowIds);
    _pageNumber = queue.answered - _skipped + 1;
    _pageTotal = queue.estimatedTotal - _skipped;
    _step = rung.step;
    final words = _pick!.words;
    final past = words.where((w) => queue.passed(w.rowId) || queue.rungOf(w.rowId).index >= _step).length;
    _stepProgress = past / words.length;
    _publish(SessionStatus.playing);
  }

  /// Every word passed: each word's outcome, the played group remembered for
  /// the next split session (AC-07), and the boxes moved in ONE store update
  /// (ADR-0002, AC-13); the [SessionResult] goes to the results screen (AC-12).
  Future<void> _finish() async {
    final queue = _queue!;
    final pick = _pick!;
    _page = null;
    _outcomes = {
      for (final w in pick.words)
        w: !_shownRows.contains(w.rowId)
            ? WordOutcome.unused
            : queue.missed(w.rowId)
                ? WordOutcome.missed
                : WordOutcome.clean,
    };
    final index = pick.groupIndex;
    if (_split && index != null) {
      unawaited(ref.read(learnLastGroupNotifierProvider(_collection.collectionId).notifier).set(index));
    }
    final store = await ref.read(collectionStoreProvider.future);
    if (_disposed) return;
    final result = await finishSession(
      store: store,
      collectionId: _collection.collectionId,
      outcomes: _outcomes,
      kind: SessionKind.exercises,
      groupIndex: _split ? index : null,
      groupCount: _split ? pick.groupCount : 0,
      pages: _pageIndex,
    );
    if (_disposed) return;
    ref.read(lastSessionResultProvider.notifier).set(result);
    _publish(SessionStatus.finished);
  }

  void _publish(SessionStatus status) {
    if (_disposed) return;
    state = LearningSessionState(
      status: status,
      pick: _pick,
      queue: _queue,
      page: status == SessionStatus.playing ? _page : null,
      answer: status == SessionStatus.playing ? _answer : null,
      pageIndex: _pageIndex,
      verdict: _verdict,
      pageNumber: _pageNumber,
      pageTotal: _pageTotal,
      step: _step,
      stepProgress: _stepProgress,
      loadFailed: _failed.isNotEmpty,
      outcomes: _outcomes,
    );
  }
}
