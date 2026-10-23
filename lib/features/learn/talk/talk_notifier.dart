import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/story_run.dart';
import '../../../core/models/word_collection.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/talk_api_service.dart';
import '../session/session_result.dart';
import '../session/session_words.dart';
import 'talk_rules.dart';

part 'talk_notifier.g.dart';

/// The line shown when the day's talks are used up (AC-24).
const talkDayLimitMessage = "Today's talk limit is reached. Try again tomorrow.";

/// The one error line for a turn that failed for any other reason.
const talkFailedMessage = 'Could not reach the AI. Check the connection and try again.';

/// The line when the collection has no words to talk about.
const talkNoWordsMessage = 'Add words with a translation to start learning';

/// The Worker takes 1–19 words a turn (ADR-0007).
const int talkMaxWords = 19;

/// Where a talk stands (screens.md SCR-06): setting the scene, waiting for
/// the learner, waiting for the AI, refused for the day, failed (Retry), or
/// ended.
enum TalkStatus { starting, talking, waiting, limit, error, over }

enum TalkRole { ai, learner }

class TalkMessage {
  const TalkMessage(this.role, this.text);

  final TalkRole role;
  final String text;
}

/// One word of the word strip: ticked once the learner's own reply used it.
class TalkStripWord {
  const TalkStripWord(this.word, {this.used = false});

  final WordPair word;
  final bool used;
}

class TalkState {
  const TalkState({
    this.status = TalkStatus.starting,
    this.messages = const [],
    this.words = const [],
    this.target,
    this.hintWord,
    this.hinted = const {},
    this.repliesCount = 0,
    this.repliesWithoutTarget = 0,
    this.errorText,
    this.keepDraft,
  });

  final TalkStatus status;
  final List<TalkMessage> messages;
  final List<TalkStripWord> words;

  /// The word the AI steers toward now; null when it named none of the words.
  final String? target;

  /// The word the shown Hint offers ("Try using: …"); null until Hint is tapped.
  final String? hintWord;

  /// Row ids whose hint was shown: used after it they count as a miss (AC-22).
  final Set<String> hinted;

  /// Learner replies sent so far (the "2 / 12" counter).
  final int repliesCount;

  /// Learner replies since the current target without it (AC-21).
  final int repliesWithoutTarget;
  final String? errorText;

  /// The typed text of a reply that failed, kept for Retry.
  final String? keepDraft;

  int get usedCount => words.where((w) => w.used).length;

  /// Whether Hint is enabled (AC-21): two replies without an unused target.
  bool get hintAvailable =>
      target != null &&
      words.any((w) => w.word.word == target && !w.used) &&
      hintDue(repliesWithoutTarget);

  TalkState copyWith({
    TalkStatus? status,
    List<TalkMessage>? messages,
    List<TalkStripWord>? words,
    String? Function()? target,
    String? Function()? hintWord,
    Set<String>? hinted,
    int? repliesCount,
    int? repliesWithoutTarget,
    String? Function()? errorText,
    String? Function()? keepDraft,
  }) =>
      TalkState(
        status: status ?? this.status,
        messages: messages ?? this.messages,
        words: words ?? this.words,
        target: target == null ? this.target : target(),
        hintWord: hintWord == null ? this.hintWord : hintWord(),
        hinted: hinted ?? this.hinted,
        repliesCount: repliesCount ?? this.repliesCount,
        repliesWithoutTarget: repliesWithoutTarget ?? this.repliesWithoutTarget,
        errorText: errorText == null ? this.errorText : errorText(),
        keepDraft: keepDraft == null ? this.keepDraft : keepDraft(),
      );
}

/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]), sets the scene from stored
/// text ([scenePick]), ticks words from the learner's own replies only
/// ([usedWords]) and, at [finish], moves the boxes once ([finishSession]).
/// Leaving without [finish] writes nothing (AC-22).
@riverpod
class Talk extends _$Talk {
  String? _id;
  String _scene = '';
  SessionPick? _pick;
  bool _split = true;
  bool _finished = false;
  bool _disposed = false;

  @override
  TalkState build(String? collectionId) {
    ref.onDispose(() => _disposed = true);
    return const TalkState();
  }

  void _set(TalkState s) {
    if (!_disposed) state = s;
  }

  List<WordPair> get _words => [for (final w in state.words) w.word];

  List<TalkWord> get _wire => [for (final w in state.words) (word: w.word.word, translation: w.word.translation)];

  /// Picks the words, builds the scene and asks for the opening.
  Future<void> start({required bool split, DateTime? now}) async {
    _split = split;
    _finished = false;
    _set(const TalkState());
    final store = await ref.read(collectionStoreProvider.future);
    final id = collectionId ?? await store.currentCollectionId();
    final c = id == null ? null : await store.byId(id);
    if (id == null || c == null) {
      _set(const TalkState(status: TalkStatus.error, errorText: talkFailedMessage));
      return;
    }
    _id = id;
    final settings = ref.read(learnSettingsNotifierProvider.notifier);
    final lastGroup = ref.read(learnLastGroupNotifierProvider(id).notifier);
    await settings.loaded;
    await lastGroup.loaded;
    final pick = pickSessionWords(
      c,
      split: split,
      wordsPerSession: ref.read(learnSettingsNotifierProvider).wordsPerSession.count,
      lastGroup: ref.read(learnLastGroupNotifierProvider(id)),
      now: now ?? DateTime.now(),
    );
    _pick = pick;
    final words = pick.words.take(talkMaxWords).toList();
    if (words.isEmpty) {
      _set(const TalkState(status: TalkStatus.error, errorText: talkNoWordsMessage));
      return;
    }
    _scene = scenePick(
      storyText: await _storyText(c, words),
      dialogueText: c.dialogues.where((d) => !d.hidden && d.lines.isNotEmpty).firstOrNull?.lines.join('\n'),
      name: c.name ?? '',
      description: c.description ?? '',
    );
    _set(TalkState(words: [for (final w in words) TalkStripWord(w)], target: words.first.word));
    await _open();
  }

  Future<void> _open() async {
    _set(state.copyWith(status: TalkStatus.starting, errorText: () => null));
    try {
      final turn = await ref.read(talkApiServiceProvider).start(scene: _scene, words: _wire, target: state.target!);
      _set(state.copyWith(
        status: TalkStatus.talking,
        messages: [TalkMessage(TalkRole.ai, turn.reply)],
        target: () => _targetOf(turn.target) ?? state.target,
      ));
    } on TalkApiException catch (e) {
      _set(e.error == TalkApiError.dayLimit
          ? state.copyWith(status: TalkStatus.limit, errorText: () => talkDayLimitMessage)
          : state.copyWith(status: TalkStatus.error, errorText: () => talkFailedMessage));
    } catch (_) {
      _set(state.copyWith(status: TalkStatus.error, errorText: () => talkFailedMessage));
    }
  }

  /// The story text of the story group holding most of [words], if any.
  Future<String?> _storyText(WordCollection c, List<WordPair> words) async {
    final ids = {for (final w in words) w.rowId};
    var best = 0;
    String? runId;
    for (final g in c.groups) {
      if (g.storyRunId == null) continue;
      final n = g.rowIds.where(ids.contains).length;
      if (n > best) (best, runId) = (n, g.storyRunId);
    }
    if (runId == null) return null;
    final run = await (await ref.read(storyRunStoreProvider.future)).byId(runId);
    if (run == null || run.kind != StoryRunKind.story) return null;
    return run.steps.where((s) => s.role == 'story' && s.outcome == 'done' && s.text != null).lastOrNull?.text;
  }

  /// [target] as one of the talk's words; null when it is none of them.
  String? _targetOf(String target) {
    final t = target.trim();
    return state.words.any((w) => w.word.word == t) ? t : null;
  }

  /// Sends the learner's reply: ticks the words it uses, counts it, ends the
  /// talk after 12 replies or once every word is used, else asks the AI. A
  /// failed turn undoes the reply and keeps its text in [TalkState.keepDraft].
  Future<void> send(String text) async {
    final reply = text.trim();
    if (reply.isEmpty || _finished) return;
    if (state.status != TalkStatus.talking && state.status != TalkStatus.error) return;
    final before = state;
    final used = usedWords(reply, _words);
    final targetRow = state.words.where((w) => w.word.word == state.target).firstOrNull?.word.rowId;
    final next = state.copyWith(
      status: TalkStatus.waiting,
      messages: [...state.messages, TalkMessage(TalkRole.learner, reply)],
      words: [for (final w in state.words) TalkStripWord(w.word, used: w.used || used.contains(w.word.rowId))],
      repliesCount: state.repliesCount + 1,
      repliesWithoutTarget: targetRow != null && used.contains(targetRow) ? 0 : state.repliesWithoutTarget + 1,
      errorText: () => null,
      keepDraft: () => null,
    );
    _set(next);
    if (talkOver(next.repliesCount, next.usedCount, next.words.length)) {
      await finish();
      return;
    }
    try {
      final turn = await ref.read(talkApiServiceProvider).reply(
            scene: _scene,
            words: _wire,
            target: next.target ?? next.words.firstWhere((w) => !w.used, orElse: () => next.words.first).word.word,
            history: capHistory([
              for (final m in next.messages) TalkLine(role: m.role == TalkRole.ai ? 'ai' : 'learner', text: m.text),
            ]),
          );
      final target = _targetOf(turn.target);
      final moved = target != next.target;
      _set(state.copyWith(
        status: TalkStatus.talking,
        messages: [...state.messages, TalkMessage(TalkRole.ai, turn.reply)],
        target: () => target,
        hintWord: moved ? () => null : null,
        repliesWithoutTarget: moved ? 0 : null,
      ));
    } catch (_) {
      _set(before.copyWith(status: TalkStatus.error, errorText: () => talkFailedMessage, keepDraft: () => reply));
    }
  }

  /// Retry after an error: the opening again, or the kept reply.
  Future<void> retry() async {
    if (state.status != TalkStatus.error) return;
    if (state.messages.isEmpty) {
      if (state.words.isEmpty) return start(split: _split);
      return _open();
    }
    final draft = state.keepDraft;
    if (draft != null) await send(draft);
  }

  /// Shows the Hint: the current target, which now counts as a miss if used.
  void showHint() {
    final row = state.words.where((w) => w.word.word == state.target).firstOrNull?.word.rowId;
    if (row == null) return;
    _set(state.copyWith(hintWord: () => state.target, hinted: {...state.hinted, row}));
  }

  /// Done, or the talk's own end: scores the words (AC-22), moves the boxes in
  /// one store write and hands the result to the results screen. Runs once.
  Future<void> finish({DateTime? now}) async {
    if (_finished || state.words.isEmpty || _id == null) return;
    _finished = true;
    final store = await ref.read(collectionStoreProvider.future);
    final pick = _pick;
    final result = await finishSession(
      store: store,
      collectionId: _id,
      outcomes: scoreTalk(_words, used: {for (final w in state.words) if (w.used) w.word.rowId}, hinted: state.hinted),
      kind: SessionKind.talk,
      now: now,
      groupIndex: pick?.groupIndex,
      groupCount: pick?.groupCount ?? 0,
    );
    if (_disposed) return;
    ref.read(lastSessionResultProvider.notifier).set(result);
    final index = pick?.groupIndex;
    if (result.written && index != null) {
      await ref.read(learnLastGroupNotifierProvider(_id!).notifier).set(index);
    }
    _set(state.copyWith(status: TalkStatus.over));
  }
}
