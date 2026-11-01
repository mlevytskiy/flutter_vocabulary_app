import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_box.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/models/word_result.dart';
import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart' show LearnDataKind;
import '../../../core/services/talk_api_service.dart';
import '../flow/learn_flow_notifier.dart';
import '../session/leitner.dart' show WordOutcome, WordRating, boxOf, isFlagged;
import '../session/self_check.dart';
import '../session/session_result.dart';
import '../session/session_words.dart';
import 'talk_quiz.dart';
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

/// The `WordResult.exerciseId` of the Learn flow's main dialog
/// (learn-welcome AC-14).
const String talkExerciseId = 'talk';

/// How a talk word's outcome reads as a main dialog result (learn-welcome
/// AC-14): clean → used, hinted → after hint, missed → missed, unused.
DialogWordResult dialogResultOf(WordOutcome outcome) => switch (outcome) {
      WordOutcome.clean => DialogWordResult.used,
      WordOutcome.hinted => DialogWordResult.afterHint,
      WordOutcome.missed => DialogWordResult.missed,
      WordOutcome.unused => DialogWordResult.unused,
    };

/// Where a talk stands (screens.md SCR-06): setting the scene, waiting for
/// the learner, waiting for the AI, refused for the day, failed (Retry), or
/// ended.
enum TalkStatus { starting, talking, waiting, limit, error, over }

enum TalkRole { ai, learner }

class TalkMessage {
  const TalkMessage(this.role, this.text, {this.isChoice = false});

  final bool isChoice;
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
    this.interaction,
    this.choices = const [],
    this.speakingPrompt = '',
    this.keepChoice = false,
    this.quizzes = const [],
    this.quizzedRows = const {},
    this.replyLimit,
    this.grammarRight = 0,
    this.grammarWrong = 0,
  });

  /// The main dialog's grammar verdicts so far (learn-warm-up-v2 AC-10):
  /// learner lines a reply judged right / wrong; unsure ones are left out.
  final int grammarRight;
  final int grammarWrong;

  /// The Learn flow's main dialog's reply limit (6 or 12, learn-welcome
  /// AC-13) for the counter; null in a plain talk.
  final int? replyLimit;

  /// The quick checks of this talk (owner, 2026-10-24), each after the
  /// message count [at]; a null quiz is still loading.
  final List<({int at, TalkQuiz? quiz})> quizzes;

  /// Row ids a quiz has already covered.
  final Set<String> quizzedRows;

  /// The quiz the learner is in: the last one, until they go back to the talk.
  ({int at, TalkQuiz? quiz})? get openQuiz {
    final last = quizzes.lastOrNull;
    return last == null || (last.quiz?.closed ?? false) ? null : last;
  }

  /// The open quiz's step when it is answered by voice or typing.
  TalkQuizItem? get spokenQuizItem {
    final item = openQuiz?.quiz?.current;
    return item != null && item.spoken && !item.done ? item : null;
  }

  final String? interaction;
  final List<String> choices;
  final String speakingPrompt;
  final bool keepChoice;
  bool get mixed => interaction != null;
  bool get complete => interaction == 'complete';

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
      (interaction == 'speak' || hintDue(repliesWithoutTarget));

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
    String? interaction,
    List<String>? choices,
    String? speakingPrompt,
    bool? keepChoice,
    List<({int at, TalkQuiz? quiz})>? quizzes,
    Set<String>? quizzedRows,
    int? grammarRight,
    int? grammarWrong,
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
        interaction: interaction ?? this.interaction,
        choices: choices ?? this.choices,
        speakingPrompt: speakingPrompt ?? this.speakingPrompt,
        keepChoice: keepChoice ?? this.keepChoice,
        quizzes: quizzes ?? this.quizzes,
        quizzedRows: quizzedRows ?? this.quizzedRows,
        replyLimit: replyLimit,
        grammarRight: grammarRight ?? this.grammarRight,
        grammarWrong: grammarWrong ?? this.grammarWrong,
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
///
/// With [learnFlow] it is the Learn flow's main dialog (learn-welcome AC-13,
/// AC-14; [startFlow]): the words, topic, reply limit and picture come from
/// [learnFlowDialogSetupProvider], and [finish] hands each word's
/// [DialogWordResult] to the flow and writes `WordResult`s, never a box.
@riverpod
class Talk extends _$Talk {
  String? _id;
  String _scene = '';
  SessionPick? _pick;
  bool _split = true;
  bool _finished = false;
  bool _disposed = false;

  /// Set while the closing check is open: the talk finishes once it closes.
  bool _finishOnClose = false;

  /// The main dialog's topic and reply limit; null in a plain talk.
  TalkTopic? _topic;
  int? _maxReplies;

  /// The main dialog's grammar rule (learn-warm-up-v2 AC-09), sent on the
  /// start and every reply; null without one and in a plain talk.
  String? _grammar;

  /// The talk words' boxes when the talk started (by rowId), kept up to date
  /// by the main dialog's self-check ratings; a new word has none.
  Map<String, WordBox> _boxes = const {};

  /// The self-check ratings of a plain talk (by rowId), handed to
  /// [finishSession] (self-check-cards AC-11).
  final Map<String, WordRating> _ratings = {};

  /// Keeps the boxes of [words] from [stored] and forgets earlier ratings.
  void _keepBoxes(List<WordPair> words, List<WordBox> stored) {
    _ratings.clear();
    _boxes = {
      for (final w in words)
        if (boxOf(stored, w) case final b?) w.rowId: b,
    };
  }

  @override
  TalkState build(String? collectionId, {bool learnFlow = false}) {
    ref.onDispose(() => _disposed = true);
    return const TalkState();
  }

  void _set(TalkState s) {
    if (!_disposed) state = s;
  }

  List<WordPair> get _words => [for (final w in state.words) w.word];

  List<TalkWord> get _wire => [for (final w in state.words) (word: w.word.word, translation: w.word.translation)];

  /// The Learn flow's main dialog (learn-welcome AC-13): the flow's chosen
  /// words, in order (the first is the target), its topic and reply limit,
  /// and the picture drawn during the cards (no second picture request).
  Future<void> startFlow() async {
    _finished = false;
    _set(const TalkState());
    final store = await ref.read(collectionStoreProvider.future);
    final id = collectionId ?? await store.currentCollectionId();
    if (id == null) {
      _set(const TalkState(status: TalkStatus.error, errorText: talkFailedMessage));
      return;
    }
    // Kept listened while the talk lives: the picture may still be drawing.
    final sub = ref.listen<LearnDialogSetup?>(learnFlowDialogSetupProvider(id), (_, next) {
      if (next == null || next.pictureLoading || _disposed) return;
      if (state.pictureLoading) _set(state.copyWith(picture: next.picture, pictureLoading: false));
    });
    final setup = sub.read();
    final c = await store.byId(id);
    final words = setup?.words.take(talkMaxWords).toList() ?? const <WordPair>[];
    if (setup == null || words.isEmpty) {
      _set(const TalkState(status: TalkStatus.error, errorText: talkFailedMessage));
      return;
    }
    _id = id;
    _topic = (id: setup.topic.id, text: setup.topic.text);
    _maxReplies = setup.maxReplies;
    _grammar = setup.grammarRule;
    _scene = scenePick(name: c?.name ?? '', description: c?.description ?? '');
    _keepBoxes(words, c?.boxes ?? const []);
    _set(TalkState(
      words: [for (final w in words) TalkStripWord(w)],
      target: words.first.word,
      name: c?.name ?? '',
      picture: setup.picture,
      pictureLoading: setup.pictureLoading,
      replyLimit: setup.maxReplies,
    ));
    await _open();
  }

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
    _keepBoxes(words, c.boxes);
    _set(TalkState(words: [for (final w in words) TalkStripWord(w)], target: words.first.word, name: c.name ?? ''));
    await _open();
  }

  Future<void> _open() async {
    _set(state.copyWith(status: TalkStatus.starting, errorText: () => null));
    try {
      final turn = await ref
          .read(talkApiServiceProvider)
          .start(
              scene: _scene,
              words: _wire,
              target: state.target!,
              topic: _topic,
              maxReplies: _maxReplies,
              grammar: _grammar);
      final mission = turn.mission;
      if (mission != null && !learnFlow) {
        // Only the mission's words are talked about; the rest keep their boxes.
        final keep = {for (final w in mission.words) w.trim().toLowerCase()};
        final words = [
          for (final w in state.words)
            if (keep.contains(w.word.word.trim().toLowerCase())) w
        ];
        if (words.isNotEmpty) _set(state.copyWith(words: words));
      }
      if (mission != null) {
        _scene = '${mission.role}\nGoal: ${mission.goal}\n${mission.brief}\nVisible scene: ${mission.picture}';
      }
      _set(state.copyWith(
        status: TalkStatus.talking,
        messages: [TalkMessage(TalkRole.ai, turn.reply)],
        target: () => _targetOf(turn.target) ?? state.target,
        mission: mission,
        interaction: turn.interaction,
        choices: turn.choices,
        speakingPrompt: turn.speakingPrompt,
        // The main dialog shows the picture drawn during the cards.
        pictureLoading: learnFlow ? null : mission != null,
      ));
      if (mission != null && !learnFlow) unawaited(_drawPicture(mission.picture));
      unawaited(_maybeQuiz());
    } on TalkApiException catch (e) {
      // A main dialog refused for the day is skipped (learn-welcome AC-13).
      if (learnFlow && e.error == TalkApiError.dayLimit) _flow?.dialogRefused();
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
  Future<void> send(String text, {bool isChoice = false}) async {
    final reply = text.trim();
    if (reply.isEmpty || _finished || state.complete) return;
    if (isChoice && !state.choices.contains(reply)) return;
    if (state.status != TalkStatus.talking && state.status != TalkStatus.error) return;
    final before = state;
    final used = isChoice ? <String>{} : usedWords(reply, _words);
    final targetRow = state.words.where((w) => w.word.word == state.target).firstOrNull?.word.rowId;
    final next = state.copyWith(
      status: TalkStatus.waiting,
      messages: [...state.messages, TalkMessage(TalkRole.learner, reply, isChoice: isChoice)],
      words: [for (final w in state.words) TalkStripWord(w.word, used: w.used || used.contains(w.word.rowId))],
      repliesCount: state.repliesCount + 1,
      repliesWithoutTarget: targetRow != null && used.contains(targetRow) ? 0 : state.repliesWithoutTarget + 1,
      errorText: () => null,
      keepDraft: () => null,
      keepChoice: false,
    );
    _set(next);
    if (!learnFlow && !next.mixed && talkOver(next.repliesCount, next.usedCount, next.words.length)) {
      await end();
      return;
    }
    try {
      final turn = await ref.read(talkApiServiceProvider).reply(
            scene: _scene,
            words: _wire,
            target: next.target ?? next.words.firstWhere((w) => !w.used, orElse: () => next.words.first).word.word,
            history: capHistory([
              for (final m in next.messages)
                TalkLine(role: m.role == TalkRole.ai ? 'ai' : 'learner', text: m.text, isChoice: m.isChoice),
            ]),
            topic: _topic,
            maxReplies: _maxReplies,
            grammar: _grammar,
          );
      if (_finished || _disposed) return;
      final target = _targetOf(turn.target);
      final moved = target != next.target;
      // The main dialog ends at its reply limit whatever the AI said.
      final last = _maxReplies != null && next.repliesCount >= _maxReplies!;
      _set(state.copyWith(
        status: TalkStatus.talking,
        messages: [...state.messages, TalkMessage(TalkRole.ai, turn.reply)],
        target: () => target,
        interaction: last ? 'complete' : turn.interaction,
        choices: last ? const [] : turn.choices,
        speakingPrompt: last ? '' : turn.speakingPrompt,
        hintWord: moved ? () => null : null,
        repliesWithoutTarget: moved ? 0 : null,
        // Only right and wrong count (learn-warm-up-v2 AC-10).
        grammarRight: _grammar != null && turn.grammarVerdict == 'right' ? state.grammarRight + 1 : null,
        grammarWrong: _grammar != null && turn.grammarVerdict == 'wrong' ? state.grammarWrong + 1 : null,
      ));
      unawaited(_maybeQuiz());
    } catch (_) {
      if (_finished || _disposed) return;
      _set(before.copyWith(
          status: TalkStatus.error, errorText: () => talkFailedMessage, keepDraft: () => reply, keepChoice: isChoice));
    }
  }

  /// Opens a quick check once [talkQuizBatch] words have come up in the talk
  /// and none is open: the card shows at once, loading, then fills with the
  /// exercise data (sentences, definitions; cached on the Worker). Without
  /// that data every step is Translate.
  Future<void> _maybeQuiz() async {
    if (state.openQuiz != null || _finished || state.complete) return;
    final batch = quizBatch([for (final m in state.messages) m.text], _words, state.quizzedRows);
    if (batch == null) return;
    final at = state.messages.length;
    _set(state.copyWith(
      quizzes: [...state.quizzes, (at: at, quiz: null)],
      quizzedRows: {...state.quizzedRows, for (final w in batch) w.rowId},
    ));
    final wire = [for (final w in batch) (rowId: w.rowId, word: w.word, translation: w.translation)];
    final api = ref.read(learnApiServiceProvider);
    Map<String, String> sentences = const {}, definitions = const {};
    try {
      final (s, d) = await (
        api.fetchData(LearnDataKind.sentence, wire),
        api.fetchData(LearnDataKind.definition, wire),
      ).wait;
      sentences = {
        for (final e in s.entries)
          if (e.value != null) e.key: e.value!.sentence
      };
      definitions = {
        for (final e in d.entries)
          if (e.value != null) e.key: e.value!.definition
      };
    } catch (_) {
      // Translate needs no data.
    }
    if (_disposed) return;
    final quiz = TalkQuiz(items: buildTalkQuiz(batch, sentences: sentences, definitions: definitions));
    _setQuiz(quiz);
  }

  void _setQuiz(TalkQuiz quiz) {
    final open = state.openQuiz;
    if (open == null) return;
    _set(state.copyWith(quizzes: [
      for (final q in state.quizzes) identical(q, open) ? (at: q.at, quiz: quiz) : q,
    ]));
  }

  /// A said, typed or picked answer to the open quiz's step.
  void answerQuiz(String answer) {
    final quiz = state.openQuiz?.quiz;
    if (quiz == null) return;
    final item = quiz.current;
    if (item.done || item.kind == TalkQuizKind.matchDefinitions) return;
    final right = item.kind == TalkQuizKind.pickAnswer
        ? answer.trim().toLowerCase() == item.word.word.trim().toLowerCase()
        : quizAnswerRight(answer, item.word.word);
    _setQuiz(_withSelfChecks(quiz.withCurrent(item.copyWith(answer: answer.trim(), correct: right))));
  }

  /// Match definitions: [rowId]'s word put on the definition of [definitionRowId].
  void matchQuiz(String rowId, String definitionRowId) {
    final quiz = state.openQuiz?.quiz;
    if (quiz == null) return;
    final item = quiz.current;
    if (item.kind != TalkQuizKind.matchDefinitions || item.matched.contains(rowId)) return;
    _setQuiz(_withSelfChecks(quiz.withCurrent(rowId == definitionRowId
        ? item.copyWith(matched: {...item.matched, rowId})
        : item.copyWith(wrongRows: {...item.wrongRows, rowId}))));
  }

  /// Once [quiz]'s exercise steps are all answered, a self-check step for
  /// each talk word flagged so far — missed (a wrong answer) or used only
  /// after its hint — that no quick check has given one yet
  /// (self-check-cards AC-11). A word flagged later waits for the next quick
  /// check or the closing check ([end]); ending early leaves it unrated (AC-09).
  TalkQuiz _withSelfChecks(TalkQuiz quiz) {
    if (!quiz.exercisesDone) return quiz;
    final steps = _selfCheckSteps(quiz);
    return steps.isEmpty ? quiz : quiz.copyWith(items: [...quiz.items, ...steps]);
  }

  /// A self-check step for each talk word flagged so far that no quick check
  /// gave one yet, [extra] (a quiz not in the state yet) counted too.
  List<TalkQuizItem> _selfCheckSteps(TalkQuiz? extra) {
    final checked = {
      for (final q in state.quizzes) ...?q.quiz?.checkedRows,
      ...?extra?.checkedRows,
    };
    final outcomes = _outcomesWith(extra);
    final flagged = [
      for (final e in outcomes.entries)
        if (isFlagged(e.value) && !checked.contains(e.key.rowId)) e.key
    ];
    if (flagged.isEmpty) return const [];
    final missed = {
      for (final e in outcomes.entries)
        if (e.value == WordOutcome.missed) e.key.rowId
    };
    return selfCheckSteps(flagged, boxes: _boxes, missedRows: missed);
  }

  /// The talk's own end — its last reply, or See results after the AI closed
  /// it: a word flagged after the last quick check gets its self-check step
  /// first, in a closing check of only those steps, and the talk finishes
  /// when that check closes (self-check-cards AC-11). Without such a word,
  /// [finish] at once. The header's End stays [finish]: ending early leaves
  /// a flagged word unrated (AC-09).
  Future<void> end() async {
    if (_finished || _finishOnClose) return;
    final steps = state.openQuiz == null ? _selfCheckSteps(null) : const <TalkQuizItem>[];
    if (steps.isEmpty) return finish();
    _finishOnClose = true;
    _set(state.copyWith(
      status: TalkStatus.talking,
      quizzes: [...state.quizzes, (at: state.messages.length, quiz: TalkQuiz(items: steps))],
    ));
  }

  /// Finishes the talk once its closing check has closed.
  Future<void> _finishIfClosed() async {
    if (_finishOnClose && state.openQuiz == null) await finish();
  }

  /// The open quiz's self-check step rated (self-check-cards AC-11): in a
  /// plain talk the rating waits for [finish] to move the box; in the main
  /// dialog it moves the box at once in one store write (learn-welcome
  /// ADR-0004), like the flow's cards. Then on to the next step, or back to
  /// the talk after the last.
  Future<void> rateQuiz(SelfRating rating) async {
    final quiz = state.openQuiz?.quiz;
    if (quiz == null || _finished) return;
    final item = quiz.current;
    if (item.kind != TalkQuizKind.selfCheck || item.done) return;
    final rated = quiz.withCurrent(item.copyWith(rating: rating));
    _setQuiz(rated.isLast ? rated.copyWith(closed: true) : rated.copyWith(index: rated.index + 1));
    final row = item.word;
    if (!learnFlow) {
      _ratings[row.rowId] = (rating: rating, side: item.side);
      return _finishIfClosed();
    }
    final now = ref.read(learnFlowClockProvider)();
    _boxes = {
      ..._boxes,
      row.rowId: rateBox(row, _boxes[row.rowId], rating, now, side: item.side, afterMistake: item.afterMistake),
    };
    final store = await ref.read(collectionStoreProvider.future);
    await store.update(_id!, (c) {
      final box = rateBox(row, boxOf(c.boxes, row), rating, now, side: item.side, afterMistake: item.afterMistake);
      c.boxes = [
        for (final b in c.boxes)
          if (b.rowId != row.rowId) b,
        box,
      ];
    });
    await _finishIfClosed();
  }

  /// The next step of the open quiz, or back to the talk after the last.
  void nextQuiz() {
    final quiz = state.openQuiz?.quiz;
    if (quiz == null || !quiz.current.done) return;
    _setQuiz(quiz.isLast ? quiz.copyWith(closed: true) : quiz.copyWith(index: quiz.index + 1));
    unawaited(_finishIfClosed());
  }

  /// Retry after an error: the opening again, or the kept reply.
  Future<void> retry() async {
    if (state.status != TalkStatus.error) return;
    if (state.messages.isEmpty) {
      if (state.words.isEmpty) return learnFlow ? startFlow() : start(split: _split);
      return _open();
    }
    final draft = state.keepDraft;
    if (draft != null) await send(draft, isChoice: state.keepChoice);
  }

  /// Shows the Hint: the current target, which now counts as a miss if used.
  void showHint() {
    final row = state.words.where((w) => w.word.word == state.target).firstOrNull?.word.rowId;
    if (row == null) return;
    _set(state.copyWith(hintWord: () => state.target, hinted: {...state.hinted, row}));
  }

  /// The flow this main dialog belongs to; null in a plain talk.
  LearnFlow? get _flow => learnFlow && _id != null ? ref.read(learnFlowProvider(_id!).notifier) : null;

  /// Each talk word's outcome (AC-22): a quiz answer counts too, right is a
  /// use, wrong a miss (owner, 2026-10-24).
  Map<WordPair, WordOutcome> get _outcomes => _outcomesWith(null);

  /// [_outcomes] with [extra], a quiz not in the state yet, counted too.
  Map<WordPair, WordOutcome> _outcomesWith(TalkQuiz? extra) {
    final quizzes = <TalkQuiz>[
      for (final q in state.quizzes)
        if (q.quiz case final quiz?) quiz,
      if (extra != null) extra,
    ];
    return scoreTalk(_words,
        used: {
          for (final w in state.words)
            if (w.used) w.word.rowId,
          for (final q in quizzes) ...q.rightRows,
          for (final q in quizzes) ...q.wrongRows,
        },
        hinted: state.hinted,
        missed: {
          for (final q in quizzes) ...q.wrongRows,
        });
  }

  /// Done, or the talk's own end: scores the words (AC-22), moves the boxes in
  /// one store write and hands the result to the results screen. Runs once.
  /// The Learn flow's main dialog moves no box (learn-welcome AC-14): each
  /// word's [DialogWordResult] goes to the flow and a used word gets a
  /// `WordResult` (known when clean, repeat after a hint or a miss).
  Future<void> finish({DateTime? now}) async {
    if (_finished || state.words.isEmpty || _id == null) return;
    _finished = true;
    if (learnFlow) return _finishFlow();
    final store = await ref.read(collectionStoreProvider.future);
    final pick = _pick;
    final result = await finishSession(
      store: store,
      collectionId: _id,
      outcomes: _outcomes,
      ratings: {
        for (final w in _words)
          if (_ratings[w.rowId] case final r?) w: r,
      },
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

  Future<void> _finishFlow() async {
    final results = {for (final e in _outcomes.entries) e.key.rowId: dialogResultOf(e.value)};
    final sink = ref.read(examResultSinkProvider);
    for (final e in results.entries) {
      if (e.value == DialogWordResult.unused) continue;
      await sink.record(
        collectionId: _id,
        rowId: e.key,
        exerciseId: talkExerciseId,
        label: e.value == DialogWordResult.used ? WordResultLabel.known : WordResultLabel.repeat,
      );
    }
    if (_disposed) return;
    _flow?.recordDialog(results, grammarRight: state.grammarRight, grammarWrong: state.grammarWrong);
    _set(state.copyWith(status: TalkStatus.over));
  }
}
