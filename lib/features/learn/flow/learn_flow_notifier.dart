import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/story_run.dart';
import '../../../core/models/word_box.dart';
import '../../../core/models/word_collection.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/learn_topics_service.dart';
import '../../../core/story/story_run_tracker.dart';
import '../../../core/story/word_grouping.dart' show wordsToLearn;
import '../../words/words_notifier.dart';
import '../session/leitner.dart';
import '../session/self_check.dart';
import 'flow_stories.dart';
import 'flow_words.dart';
import 'story_slots.dart';

part 'learn_flow_notifier.g.dart';

/// The flow's clock; tests pin it.
final learnFlowClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// A collection needs this many words to learn before Learn opens (AC-01).
const int minFlowWords = 4;

/// The longest own topic (AC-04).
const int maxOwnTopicLength = 80;

/// The snackbar of a collection with too few words (AC-01).
const String flowTooFewWordsMessage = 'Add at least 4 words to learn';

/// Where the Learn flow stands (learn-welcome ADR-0001).
enum FlowPhase {
  /// Reading the collection.
  loading,

  /// Fewer than [minFlowWords] words: the screen shows
  /// [flowTooFewWordsMessage] and opens nothing (AC-01).
  refused,

  /// The two warm-up questions (AC-02).
  warmUp,

  /// Cards, story pages and wait pages ([LearnFlowState.slot]).
  cards,

  /// The main dialog ([LearnFlowState.dialogSetup]) (AC-13).
  dialog,

  /// The summary ([LearnFlowState.results]) (AC-15).
  results,
}

/// The answer to "What would you like to talk about?" (AC-02, AC-04): one of
/// the offered topics ([id] set) or the learner's own text ([id] null), used
/// as it is.
@immutable
class FlowTopic {
  const FlowTopic({this.id, required this.text, this.description = ''});

  final String? id;

  /// The topic's title, or the own text.
  final String text;
  final String description;

  bool get isOwn => id == null;

  @override
  bool operator ==(Object other) =>
      other is FlowTopic && other.id == id && other.text == text && other.description == description;

  @override
  int get hashCode => Object.hash(id, text, description);
}

/// How a practice word ended the main dialog (AC-14).
enum DialogWordResult { used, afterHint, missed, unused }

/// What the Talk screen runs as the main dialog (AC-13), read through
/// [learnFlowDialogSetupProvider].
@immutable
class LearnDialogSetup {
  const LearnDialogSetup({
    required this.collectionId,
    required this.topic,
    required this.mode,
    required this.maxReplies,
    required this.words,
    this.picture,
    this.pictureLoading = false,
  });

  final String collectionId;
  final FlowTopic topic;
  final FlowMode mode;

  /// Learner replies that end the dialog: Easy 6, Hard 12.
  final int maxReplies;

  /// The practice words ([dialogWords]).
  final List<WordPair> words;

  /// The mission picture drawn during the cards (proxy Q15); null when it
  /// failed or is still being drawn ([pictureLoading]).
  final Uint8List? picture;
  final bool pictureLoading;

  LearnDialogSetup withPicture(Uint8List? picture, bool loading) => LearnDialogSetup(
        collectionId: collectionId,
        topic: topic,
        mode: mode,
        maxReplies: maxReplies,
        words: words,
        picture: picture,
        pictureLoading: loading,
      );
}

/// The summary of a flow (AC-15).
@immutable
class LearnFlowResults {
  const LearnFlowResults({
    required this.ratingCounts,
    required this.movedUp,
    required this.movedDown,
    required this.storiesShown,
    required this.storiesSaved,
    required this.talk,
    required this.talkLimit,
    required this.dueTomorrow,
  });

  /// Cards per rating (every rating present, 0 when unused).
  final Map<SelfRating, int> ratingCounts;

  /// Row ids whose box went up / down (a new word rated to box 1 counts up).
  final List<String> movedUp;
  final List<String> movedDown;

  /// Stories shown in the flow (reused ones have [FlowStory.reused]), for
  /// the thumbnails.
  final List<FlowStory> storiesShown;

  /// Stories still not ready before the dialog: only in Story runs
  /// ("Story saved to Story runs").
  final List<FlowStory> storiesSaved;

  /// Practice words per dialog result (every result present).
  final Map<DialogWordResult, int> talk;

  /// The dialog was skipped: "Daily talk limit reached".
  final bool talkLimit;

  /// Words to learn whose box is due by tomorrow ("N words due tomorrow").
  final int dueTomorrow;
}

/// What the flow screen shows (ADR-0001).
@immutable
class LearnFlowState {
  const LearnFlowState({
    this.phase = FlowPhase.loading,
    this.words = const [],
    this.groups = const [],
    this.topics,
    this.topic,
    this.mode,
    this.cardsDone = 0,
    this.slot = const CardSlot(),
    this.boxes = const {},
    this.ratings = const {},
    this.stories = const [],
    this.shownStories = const [],
    this.savedStories = const [],
    this.dialogSetup,
    this.dialogResults = const {},
    this.talkLimit = false,
    this.results,
  });

  final FlowPhase phase;

  /// The card words (AC-05), in card order.
  final List<WordPair> words;

  /// [words] split into groups (AC-06).
  final List<List<WordPair>> groups;

  /// The three offered topics; null while they load (at most 4 s, AC-03).
  final List<LearnTopic>? topics;
  final FlowTopic? topic;
  final FlowMode? mode;

  /// Cards rated so far; the current card is `words[cardsDone]`.
  final int cardsDone;

  /// The page shown while [phase] is [FlowPhase.cards].
  final NextSlot slot;

  /// Each card word's box as it stands now (null: new), by row id.
  final Map<String, WordBox?> boxes;

  /// The rating each rated card got, by row id.
  final Map<String, SelfRating> ratings;

  /// The story groups' stories (at most 3).
  final List<FlowStory> stories;

  /// Indexes into [stories] of the stories shown, in order.
  final List<int> shownStories;

  /// Indexes of the stories left to Story runs.
  final List<int> savedStories;

  /// Set when [phase] reaches [FlowPhase.dialog].
  final LearnDialogSetup? dialogSetup;
  final Map<String, DialogWordResult> dialogResults;
  final bool talkLimit;

  /// Set when [phase] reaches [FlowPhase.results].
  final LearnFlowResults? results;

  /// The card shown while [slot] is a [CardSlot]; null otherwise.
  WordPair? get card =>
      phase == FlowPhase.cards && slot is CardSlot && cardsDone < words.length ? words[cardsDone] : null;

  /// The side [row]'s card shows first: 'uk' or 'en' (AC-07).
  String sideOf(WordPair row) => nextSide(boxes[row.rowId]);

  LearnFlowState copyWith({
    FlowPhase? phase,
    List<WordPair>? words,
    List<List<WordPair>>? groups,
    List<LearnTopic>? topics,
    FlowTopic? topic,
    FlowMode? mode,
    int? cardsDone,
    NextSlot? slot,
    Map<String, WordBox?>? boxes,
    Map<String, SelfRating>? ratings,
    List<FlowStory>? stories,
    List<int>? shownStories,
    List<int>? savedStories,
    LearnDialogSetup? dialogSetup,
    Map<String, DialogWordResult>? dialogResults,
    bool? talkLimit,
    LearnFlowResults? results,
  }) =>
      LearnFlowState(
        phase: phase ?? this.phase,
        words: words ?? this.words,
        groups: groups ?? this.groups,
        topics: topics ?? this.topics,
        topic: topic ?? this.topic,
        mode: mode ?? this.mode,
        cardsDone: cardsDone ?? this.cardsDone,
        slot: slot ?? this.slot,
        boxes: boxes ?? this.boxes,
        ratings: ratings ?? this.ratings,
        stories: stories ?? this.stories,
        shownStories: shownStories ?? this.shownStories,
        savedStories: savedStories ?? this.savedStories,
        dialogSetup: dialogSetup ?? this.dialogSetup,
        dialogResults: dialogResults ?? this.dialogResults,
        talkLimit: talkLimit ?? this.talkLimit,
        results: results ?? this.results,
      );
}

/// The Learn flow of one collection (learn-welcome ADR-0001; AC-01, AC-08,
/// AC-09, AC-13, AC-16): warm-up → cards with story slots → main dialog →
/// results.
///
/// Built, it reads the collection, picks the card words and asks for the
/// topics. The warm-up answers ([chooseTopic] or [ownTopic], then
/// [chooseMode]) open the cards; then each of the first 3 groups reuses a
/// finished saved story with the same row ids or starts a run in the
/// background, and the mission picture is drawn. Each [rate] writes that
/// word's box at once (ADR-0004). [leave] drops everything not yet saved;
/// started runs go on into Story runs.
@riverpod
class LearnFlow extends _$LearnFlow {
  bool _disposed = false;
  bool _left = false;
  bool _cardsOpened = false;
  bool _pictureDone = false;
  Uint8List? _picture;
  StorySlots? _slots;
  StoryFollow? _follow;
  final _watches = <StreamSubscription<StoryRun?>>[];
  final Map<String, int> _beforeBox = {};
  Future<void> _writes = Future.value();

  @override
  LearnFlowState build(String collectionId) {
    ref.onDispose(() {
      _disposed = true;
      _stopFollowing();
    });
    unawaited(_load());
    return const LearnFlowState();
  }

  /// The box writes queued so far, for tests.
  @visibleForTesting
  Future<void> get saved => _writes;

  bool get _gone => _disposed || _left;

  void _set(LearnFlowState next) {
    if (!_gone) state = next;
  }

  Future<void> _load() async {
    final collection = await _collection();
    if (_gone) return;
    if (collection == null || wordsToLearn(collection).length < minFlowWords) {
      return _set(state.copyWith(phase: FlowPhase.refused));
    }
    final now = ref.read(learnFlowClockProvider)();
    final words = cardWords(wordsToLearn(collection), collection.boxes, now);
    final boxes = {for (final w in words) w.rowId: boxOf(collection.boxes, w)?.copy()};
    _set(state.copyWith(
      phase: FlowPhase.warmUp,
      words: words,
      groups: splitGroups(words),
      boxes: boxes,
    ));
    final topics = await ref.read(learnTopicsServiceProvider).pick([for (final w in words) w.word]);
    _set(state.copyWith(topics: topics));
  }

  // --- warm-up -------------------------------------------------------------

  /// Q1 answered with an offered topic.
  void chooseTopic(LearnTopic topic) {
    if (state.phase != FlowPhase.warmUp) return;
    _set(state.copyWith(topic: FlowTopic(id: topic.id, text: topic.title, description: topic.description)));
    _maybeOpenCards();
  }

  /// Q1 answered with the learner's own [text] (AC-04): taken as it is;
  /// false (nothing kept) when it is blank or longer than 80 characters.
  bool ownTopic(String text) {
    if (state.phase != FlowPhase.warmUp) return false;
    if (text.trim().isEmpty || text.length > maxOwnTopicLength) return false;
    _set(state.copyWith(topic: FlowTopic(text: text)));
    _maybeOpenCards();
    return true;
  }

  /// Q2 answered: Hard or Easy.
  void chooseMode(FlowMode mode) {
    if (state.phase != FlowPhase.warmUp) return;
    _set(state.copyWith(mode: mode));
    _maybeOpenCards();
  }

  void _maybeOpenCards() {
    if (_cardsOpened || state.topic == null || state.mode == null) return;
    _cardsOpened = true;
    final story = storyGroups(state.groups);
    final ends = <int>[];
    var at = 0;
    for (final g in story) {
      at += g.length;
      ends.add(at);
    }
    _slots = StorySlots(groupEnds: ends, totalCards: state.words.length);
    _set(state.copyWith(
      phase: FlowPhase.cards,
      stories: [
        for (var i = 0; i < story.length; i++)
          FlowStory(index: i, groupId: flowGroupId(story[i]), rowIds: [for (final w in story[i]) w.rowId]),
      ],
    ));
    _advance();
    unawaited(_startStories(story));
    unawaited(_drawPicture(state.topic!));
  }

  // --- cards ---------------------------------------------------------------

  /// Rates the current card (AC-08): the box move and the side shown are
  /// written at once in one `CollectionStore.update` (ADR-0004), then the
  /// next page is picked.
  Future<void> rate(SelfRating rating) {
    final row = state.card;
    if (row == null || _gone) return _writes;
    final now = ref.read(learnFlowClockProvider)();
    final before = state.boxes[row.rowId];
    final side = nextSide(before);
    final after = rateBox(row, before, rating, now, side: side);
    _beforeBox.putIfAbsent(row.rowId, () => before?.box ?? 0);
    _set(state.copyWith(
      cardsDone: state.cardsDone + 1,
      boxes: {...state.boxes, row.rowId: after},
      ratings: {...state.ratings, row.rowId: rating},
    ));
    _writes = _writes.then((_) => _write(row, rating, now, side));
    _advance();
    return _writes;
  }

  Future<void> _write(WordPair row, SelfRating rating, DateTime now, String side) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.update(collectionId, (c) {
      final stored = boxOf(c.boxes, row);
      final box = rateBox(row, stored, rating, now, side: side);
      c.boxes = [
        for (final b in c.boxes)
          if (b.rowId != row.rowId) b,
        box,
      ];
    });
  }

  /// The story page was seen: on to the next page.
  void storyDone() {
    if (state.phase != FlowPhase.cards || state.slot is! StorySlot) return;
    _advance();
  }

  /// "Skip, show it later" on the wait page of [story] (AC-10).
  void skipStory(int story) {
    final slots = _slots;
    if (slots == null || state.phase != FlowPhase.cards) return;
    final slot = state.slot;
    if (slot is! WaitSlot || slot.story != story) return;
    _show(slots.skip(story, cardsDone: state.cardsDone, ready: _ready));
  }

  Set<int> get _ready => {
        for (final s in state.stories)
          if (s.status == FlowStoryStatus.ready) s.index,
      };

  void _advance() {
    final slots = _slots;
    if (slots == null) return;
    _show(slots.next(cardsDone: state.cardsDone, ready: _ready));
  }

  void _show(NextSlot slot) {
    if (slot is DialogSlot) return _openDialog(slot.saved);
    _set(state.copyWith(
      slot: slot,
      shownStories: slot is StorySlot ? [...state.shownStories, slot.story] : null,
    ));
  }

  // --- stories -------------------------------------------------------------

  Future<void> _startStories(List<List<WordPair>> groups) async {
    final collection = await _collection();
    final runStore = await ref.read(storyRunStoreProvider.future);
    if (_gone || collection == null) return;
    final tracker = ref.read(storyRunTrackerProvider.notifier);
    for (var i = 0; i < groups.length; i++) {
      final runs = await runStore.newestFirst();
      if (_gone) return;
      final saved = reusableStory(collection, groups[i], runs);
      if (saved != null) {
        _setStory(i, followRun(state.stories[i].copyWith(runId: saved.runId, reused: true), saved));
        continue;
      }
      final runId = runningStory(collectionId, groups[i], runs)?.runId ??
          // A fresh start each Learn: a failed earlier run of these words
          // waits for no "Try again" here.
          await tracker.startFor(collectionId, flowWordGroup(groups[i]), replacing: true);
      if (_gone) return;
      if (runId == null) {
        _setStory(i, state.stories[i].copyWith(status: FlowStoryStatus.failed));
        continue;
      }
      _setStory(i, state.stories[i].copyWith(runId: runId, status: FlowStoryStatus.writing));
      _follow ??= tracker.follow();
      _watches.add(runStore.watch(runId).listen((run) {
        if (!_gone) _setStory(i, followRun(state.stories[i], run));
      }));
    }
  }

  void _setStory(int i, FlowStory story) {
    if (_gone) return;
    final wasReady = state.stories[i].status == FlowStoryStatus.ready;
    _set(state.copyWith(stories: [
      for (final s in state.stories) s.index == i ? story : s,
    ]));
    // A wait page opens its story by itself when it is ready (AC-10).
    final slot = state.slot;
    if (!wasReady &&
        story.status == FlowStoryStatus.ready &&
        state.phase == FlowPhase.cards &&
        slot is WaitSlot) {
      _advance();
    }
  }

  void _stopFollowing() {
    for (final w in _watches) {
      unawaited(w.cancel());
    }
    _watches.clear();
    _follow?.release();
    _follow = null;
  }

  // --- dialog --------------------------------------------------------------

  Future<void> _drawPicture(FlowTopic topic) async {
    final prompt = topic.description.isEmpty
        ? 'A friendly everyday scene for a conversation about ${topic.text}.'
        : 'A friendly everyday scene for a conversation about ${topic.text}: ${topic.description}';
    final bytes = await ref.read(talkPictureServiceProvider).draw(prompt);
    if (_gone) return;
    _picture = bytes;
    _pictureDone = true;
    final setup = state.dialogSetup;
    if (setup != null) _set(state.copyWith(dialogSetup: setup.withPicture(bytes, false)));
  }

  void _openDialog(List<int> saved) {
    final mode = state.mode!;
    final ratings = state.ratings;
    final words = dialogWords(
      state.words,
      dontRemember: {
        for (final e in ratings.entries)
          if (e.value == SelfRating.dontRemember) e.key,
      },
      hard: {
        for (final e in ratings.entries)
          if (e.value == SelfRating.hard) e.key,
      },
      mode: mode,
    );
    _set(state.copyWith(
      phase: FlowPhase.dialog,
      savedStories: saved,
      dialogSetup: LearnDialogSetup(
        collectionId: collectionId,
        topic: state.topic!,
        mode: mode,
        maxReplies: dialogReplies(mode),
        words: words,
        picture: _picture,
        pictureLoading: !_pictureDone,
      ),
    ));
  }

  /// The main dialog ended (T15): [results] per practice word's row id; a
  /// practice word missing from it counts as unused. Never moves a box
  /// (AC-14).
  void recordDialog(Map<String, DialogWordResult> results) {
    if (state.phase != FlowPhase.dialog) return;
    final setup = state.dialogSetup!;
    _finish(
      dialog: {for (final w in setup.words) w.rowId: results[w.rowId] ?? DialogWordResult.unused},
      limit: false,
    );
  }

  /// The main dialog was refused by the daily talk limit (AC-13): straight
  /// to the results with "Daily talk limit reached".
  void dialogRefused() {
    if (state.phase != FlowPhase.dialog) return;
    _finish(dialog: const {}, limit: true);
  }

  void _finish({required Map<String, DialogWordResult> dialog, required bool limit}) {
    final now = ref.read(learnFlowClockProvider)();
    final local = now.toLocal();
    final tomorrow = DateTime(local.year, local.month, local.day + 1, 12);
    final up = <String>[], down = <String>[];
    for (final e in _beforeBox.entries) {
      final after = state.boxes[e.key]?.box ?? 0;
      if (after > e.value) up.add(e.key);
      if (after < e.value) down.add(e.key);
    }
    final results = LearnFlowResults(
      ratingCounts: {
        for (final r in SelfRating.values) r: state.ratings.values.where((x) => x == r).length,
      },
      movedUp: up,
      movedDown: down,
      storiesShown: [for (final i in state.shownStories) state.stories[i]],
      storiesSaved: [for (final i in state.savedStories) state.stories[i]],
      talk: {
        for (final r in DialogWordResult.values) r: dialog.values.where((x) => x == r).length,
      },
      talkLimit: limit,
      dueTomorrow: _dueBy(tomorrow),
    );
    _set(state.copyWith(
      phase: FlowPhase.results,
      dialogResults: dialog,
      talkLimit: limit,
      results: results,
    ));
  }

  WordCollection? _loaded;

  int _dueBy(DateTime day) {
    final collection = _loaded;
    if (collection == null) return 0;
    var count = 0;
    for (final w in wordsToLearn(collection)) {
      final box = state.boxes.containsKey(w.rowId) ? state.boxes[w.rowId] : boxOf(collection.boxes, w);
      if (isDue(box, day)) count++;
    }
    return count;
  }

  // --- leave ---------------------------------------------------------------

  /// Back, confirmed in the leave dialog (AC-16): the ratings already
  /// written stay, started runs go on into Story runs (the tracker collects
  /// them), the warm-up answers and the dialog are dropped. The flow takes
  /// no more calls.
  void leave() {
    if (_left) return;
    _left = true;
    _stopFollowing();
  }

  // --- helpers -------------------------------------------------------------

  /// The current collection's live object, or the stored one.
  Future<WordCollection?> _collection() async {
    if (_loaded != null) return _loaded;
    final current = await _readOnce(wordsProvider.future);
    if (current.collectionId == collectionId) return _loaded = current;
    final store = await ref.read(collectionStoreProvider.future);
    return _loaded = await store.byId(collectionId);
  }

  Future<T> _readOnce<T>(ProviderListenable<Future<T>> provider) async {
    final sub = ref.listen(provider, (_, __) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }
}

/// The main dialog's setup for the Talk notifier (ADR-0001, T15); null until
/// the flow of [collectionId] reaches the dialog.
@riverpod
LearnDialogSetup? learnFlowDialogSetup(Ref ref, String collectionId) =>
    ref.watch(learnFlowProvider(collectionId).select((s) => s.dialogSetup));
