import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    this.name = '',
    this.mission,
    this.picture,
    this.pictureLoading = false,
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

  /// The collection's name, under the tutor's in the header (talk-screen-b).
  final String name;

  /// The mission the talk plays out, from the opening (talk-mission); null
  /// before it, or when the Worker sent none.
  final TalkMission? mission;

  /// The mission's opening picture once drawn, and whether it is still
  /// being drawn.
  final Uint8List? picture;
  final bool pictureLoading;

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
    TalkMission? mission,
    Uint8List? picture,
    bool? pictureLoading,
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
        name: name,
        mission: mission ?? this.mission,
        picture: picture ?? this.picture,
        pictureLoading: pictureLoading ?? this.pictureLoading,
      );
}

/// Talk with AI (learn-redesign AC-20 – AC-24, sad §6.4). A null
/// [collectionId] is the current collection. The talk takes the words a
/// learning session would ([pickSessionWords]) and sends the collection's
/// name and description as the topic ([scenePick]); the Worker plans a
/// mission on 4–6 of them (talk-mission, owner 2026-10-24: something new,
/// never the mnemonic story), the talk keeps only those, sends the mission's
/// hidden brief as the scene of every reply and draws its opening picture
/// meanwhile. It ticks words from the learner's own replies only
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
    final settings = ref.read(learnSettingsProvider.notifier);
    final lastGroup = ref.read(learnLastGroupProvider(id).notifier);
    await settings.loaded;
    await lastGroup.loaded;
    final pick = pickSessionWords(
      c,
      split: split,
      wordsPerSession: ref.read(learnSettingsProvider).wordsPerSession.count,
      lastGroup: ref.read(learnLastGroupProvider(id)),
      now: now ?? DateTime.now(),
    );
    _pick = pick;
    final words = pick.words.take(talkMaxWords).toList();
    if (words.isEmpty) {
      _set(const TalkState(status: TalkStatus.error, errorText: talkNoWordsMessage));
      return;
    }
    _scene = scenePick(name: c.name ?? '', description: c.description ?? '');
    _set(TalkState(words: [for (final w in words) TalkStripWord(w)], target: words.first.word, name: c.name ?? ''));
    await _open();
  }

  Future<void> _open() async {
    _set(state.copyWith(status: TalkStatus.starting, errorText: () => null));
    try {
      final turn = await ref.read(talkApiServiceProvider).start(scene: _scene, words: _wire, target: state.target!);
      final mission = turn.mission;
      if (mission != null) {
        // Only the mission's words are talked about; the rest keep their boxes.
        final keep = {for (final w in mission.words) w.trim().toLowerCase()};
        final words = [for (final w in state.words) if (keep.contains(w.word.word.trim().toLowerCase())) w];
        if (words.isNotEmpty) _set(state.copyWith(words: words));
        _scene = mission.brief;
      }
      _set(state.copyWith(
        status: TalkStatus.talking,
        messages: [TalkMessage(TalkRole.ai, turn.reply)],
        target: () => _targetOf(turn.target) ?? state.target,
        mission: mission,
        pictureLoading: mission != null,
      ));
      if (mission != null) unawaited(_drawPicture(mission.picture));
    } on TalkApiException catch (e) {
      _set(e.error == TalkApiError.dayLimit
          ? state.copyWith(status: TalkStatus.limit, errorText: () => talkDayLimitMessage)
          : state.copyWith(status: TalkStatus.error, errorText: () => talkFailedMessage));
    } catch (_) {
      _set(state.copyWith(status: TalkStatus.error, errorText: () => talkFailedMessage));
    }
  }

  /// Draws the mission's opening picture; the talk never waits for it.
  Future<void> _drawPicture(String prompt) async {
    final bytes = await ref.read(talkPictureServiceProvider).draw(prompt);
    if (_disposed) return;
    _set(state.copyWith(picture: bytes, pictureLoading: false));
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
      await ref.read(learnLastGroupProvider(_id!).notifier).set(index);
    }
    _set(state.copyWith(status: TalkStatus.over));
  }
}
