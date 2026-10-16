import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/result_summary.dart';
import '../kit/sentence_check.dart';
import '../kit/split_rounds.dart';

part 'explain_to_friend_notifier.g.dart';

/// The frozen exercise id this exam records its Type word results under (S-02, S-55).
const explainExerciseId = 'explain-to-friend';

/// How the words are explained, chosen once per open (S-64).
enum ExplainMode { type, friend }

/// How a friend-mode word ended (S-64): Understood = known; Not yet and Skip = repeat.
enum FriendAnswer { understood, notYet, skipped }

/// One word's card: only the word is shown; the translation is for the check.
class ExplainCard {
  const ExplainCard({required this.rowId, required this.word, required this.translation});

  final String rowId;
  final String word;
  final String translation;
}

/// A word's final result: the field's [typed] result (Type) or the [friend]'s answer.
class ExplainResult {
  const ExplainResult.typed(SentenceResult this.typed) : friend = null;
  const ExplainResult.friend(FriendAnswer this.friend) : typed = null;

  final SentenceResult? typed;
  final FriendAnswer? friend;

  bool get known => typed != null ? typed!.outcome == SentenceOutcome.right : friend == FriendAnswer.understood;

  /// The summary's result text (S-48, S-65).
  String get summaryText => typed != null ? examSummaryText(typed!.outcome) : (known ? 'Known' : 'Repeat');
}

/// S-65: the detail line of a word in the summary. Pure.
String explainDetail(ExplainResult result) {
  final friend = result.friend;
  if (friend != null) {
    return switch (friend) {
      FriendAnswer.understood => 'Understood',
      FriendAnswer.notYet => 'Not yet',
      FriendAnswer.skipped => 'Skipped',
    };
  }
  final typed = result.typed!;
  if (typed.outcome == SentenceOutcome.skipped) return typed.timedOut ? 'Time up' : 'Skipped';
  return 'Yours: ${typed.sentence}';
}

/// Where the exam stands: [rounds] of cards (each shuffled once), the [mode]
/// (null until chosen), the current [round] and card [index], whether the
/// friend question is [asking], the current word's final [result] and the
/// final results of this round's words already left.
class ExplainState {
  const ExplainState({
    required this.rounds,
    this.mode,
    this.round = 0,
    this.index = 0,
    this.asking = false,
    this.result,
    this.results = const [],
  });

  final List<List<ExplainCard>> rounds;
  final ExplainMode? mode;
  final int round;
  final int index;
  final bool asking;
  final ExplainResult? result;
  final List<ExplainResult> results;

  List<ExplainCard> get cards => rounds.isEmpty ? const [] : rounds[round];
  bool get inSummary => rounds.isNotEmpty && index >= cards.length;
  ExplainCard? get card => rounds.isEmpty || mode == null || inSummary ? null : cards[index];

  /// [result] is not carried over: every caller either sets it or leaves the word.
  ExplainState copyWith({ExplainMode? mode, int? round, int? index, bool? asking, ExplainResult? result, List<ExplainResult>? results}) =>
      ExplainState(
        rounds: rounds,
        mode: mode ?? this.mode,
        round: round ?? this.round,
        index: index ?? this.index,
        asking: asking ?? this.asking,
        result: result,
        results: results ?? this.results,
      );

  ExercisePhase get phase {
    if (rounds.isEmpty) return const ExerciseNotEnough();
    if (!inSummary) return ExerciseRound(round, rounds.length);
    final known = results.where((r) => r.known).length;
    return ExerciseSummary(
      [
        for (var i = 0; i < cards.length; i++)
          WordOutcome(
            rowId: cards[i].rowId,
            word: cards[i].word,
            result: results[i].summaryText,
            detail: explainDetail(results[i]),
          ),
      ],
      hasNextRound: round + 1 < rounds.length,
      heading: examHeading(known, cards.length),
    );
  }
}

/// The explain-to-friend exam of one group (learn-explain-to-friend). No
/// Worker data: only the group's words are read. Each final Type word records
/// its result through [examResultSinkProvider] at once (S-55); friend answers
/// are shown in the summary only (S-64); nothing else is saved.
@riverpod
class ExplainToFriend extends _$ExplainToFriend {
  @override
  Future<ExplainState> build(String? collectionId, String groupId) async {
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(collectionId, groupId).future);
    final usable = <ExplainCard>[
      for (final WordPair w in words.group)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty)
          ExplainCard(rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ];
    if (usable.length < 3) return const ExplainState(rounds: []);
    return ExplainState(rounds: [for (final r in splitRounds(usable, min: 3, max: 5)) _shuffled(r, random)]);
  }

  List<ExplainCard> _shuffled(List<ExplainCard> round, Random random) => [...round]..shuffle(random);

  void retry() {
    ref.invalidate(exerciseWordsProvider(collectionId, groupId));
    ref.invalidateSelf();
  }

  /// The mode for every round of this open (S-64); asked once.
  void chooseMode(ExplainMode mode) {
    final s = state.valueOrNull;
    if (s == null || s.rounds.isEmpty || s.mode != null) return;
    state = AsyncData(s.copyWith(mode: mode));
  }

  /// Type: the current word's final result from the field. It is stored and,
  /// in the same step, recorded (S-55): once per word, never awaited, nothing
  /// for "not checked". A second call does nothing.
  void done(SentenceResult result) {
    final s = state.valueOrNull;
    final card = s?.card;
    if (s == null || card == null || s.mode != ExplainMode.type || s.result != null) return;
    state = AsyncData(s.copyWith(result: ExplainResult.typed(result)));
    final label = examLabel(result.outcome);
    if (label == null) return;
    unawaited(ref.read(examResultSinkProvider).record(
          collectionId: collectionId,
          rowId: card.rowId,
          exerciseId: explainExerciseId,
          label: label,
        ));
  }

  /// With a friend: the countdown reached zero or the learner tapped Done.
  void friendReady() {
    final s = state.valueOrNull;
    if (s == null || s.card == null || s.mode != ExplainMode.friend || s.result != null || s.asking) return;
    state = AsyncData(s.copyWith(asking: true));
  }

  /// With a friend: Understood / Not yet after the question, or Skip before
  /// it. Final once; never recorded (S-64).
  void friendAnswer(FriendAnswer answer) {
    final s = state.valueOrNull;
    if (s == null || s.card == null || s.mode != ExplainMode.friend || s.result != null) return;
    if ((answer == FriendAnswer.skipped) == s.asking) return;
    state = AsyncData(s.copyWith(result: ExplainResult.friend(answer)));
  }

  /// Leaves a final word for the next card, or the summary. Records nothing.
  void next() {
    final s = state.valueOrNull;
    final result = s?.result;
    if (s == null || result == null) return;
    state = AsyncData(s.copyWith(index: s.index + 1, asking: false, results: [...s.results, result]));
  }

  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(s.copyWith(round: s.round + 1, index: 0, asking: false, results: const []));
  }
}
