import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_words.dart';
import '../kit/gap_question.dart';
import '../kit/result_summary.dart';
import '../kit/split_rounds.dart';
import '../kit/typed_answer_field.dart';

part 'fill_the_gaps_notifier.g.dart';

/// Where fill-the-gaps stands (S-46): [rounds] of gap questions in group
/// order, the current [round] and question [index], and the final answer of
/// the current question ([result], null until it is final). Nothing is saved.
class FillState {
  const FillState({
    required this.rounds,
    this.round = 0,
    this.index = 0,
    this.result,
    this.results = const [],
  });

  final List<List<GapQuestion>> rounds;
  final int round;
  final int index;
  final TypedAnswerResult? result;

  /// The final answers of the questions of this round already left, in order.
  final List<TypedAnswerResult> results;

  List<GapQuestion> get questions => rounds.isEmpty ? const [] : rounds[round];
  bool get inSummary => rounds.isNotEmpty && index >= questions.length;
  GapQuestion? get question => rounds.isEmpty || inSummary ? null : questions[index];

  /// "1st try" 2, "2nd try" 1, "Missed" 0 (D-12, S-46).
  static String label(TypedAnswerResult r) => r.firstTry
      ? '1st try'
      : r.match.isRight && !r.gaveUp
          ? '2nd try'
          : 'Missed';

  static int points(TypedAnswerResult r) => switch (label(r)) {
        '1st try' => 2,
        '2nd try' => 1,
        _ => 0,
      };

  ExercisePhase get phase {
    if (rounds.isEmpty) return const ExerciseNotEnough();
    if (inSummary) {
      final score = results.fold<int>(0, (sum, r) => sum + points(r));
      return ExerciseSummary(
        [
          for (var i = 0; i < questions.length; i++)
            WordOutcome(rowId: questions[i].rowId, word: questions[i].answer, result: label(results[i])),
        ],
        hasNextRound: round + 1 < rounds.length,
        heading: 'Score: $score of ${2 * questions.length}',
      );
    }
    return ExerciseRound(round, rounds.length);
  }
}

@riverpod
class FillTheGaps extends _$FillTheGaps {
  @override
  Future<FillState> build(String? sessionId, String groupId) async {
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    final dialogues = await ref.watch(exerciseDialoguesProvider(sessionId).future);
    // Under 3 words to learn, or under 3 with a translation: nothing to ask.
    final candidates = <WordPair>[
      for (final w in words.group)
        if (w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty) w,
    ];
    if (candidates.length < 3) return const FillState(rounds: []);
    final questions = await loadGapQuestions(candidates, dialogues, ref.read(learnApiServiceProvider));
    final rounds = splitRounds(questions.values.toList(), min: 3, max: 9);
    return FillState(rounds: rounds);
  }

  void retry() {
    ref.invalidate(exerciseWordsProvider(sessionId, groupId));
    ref.invalidate(exerciseDialoguesProvider(sessionId));
    ref.invalidateSelf();
  }

  /// The question's final answer; a second call for the same question does nothing.
  void answer(TypedAnswerResult result) {
    final s = state.valueOrNull;
    if (s == null || s.question == null || s.result != null) return;
    state = AsyncData(FillState(rounds: s.rounds, round: s.round, index: s.index, result: result, results: s.results));
  }

  /// Leaves a final answer for the next question, or the summary.
  void next() {
    final s = state.valueOrNull;
    final result = s?.result;
    if (s == null || result == null) return;
    state = AsyncData(FillState(rounds: s.rounds, round: s.round, index: s.index + 1, results: [...s.results, result]));
  }

  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(FillState(rounds: s.rounds, round: s.round + 1));
  }
}
