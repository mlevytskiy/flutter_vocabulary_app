import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/question_builder.dart';
import '../kit/result_summary.dart';
import '../kit/split_rounds.dart';

part 'pick_the_answer_notifier.g.dart';

/// One question of a round with the word it asks about.
class PickItem {
  const PickItem({required this.word, required this.question, required this.kind});

  final String word;
  final Question question;
  final QuestionKind kind;
}

/// Where pick-the-answer stands (S-06, S-29): every round's questions are
/// built when the exercise opens; [index] is the question shown in round
/// [round], [picked] the option tapped on it, [results] the answers so far
/// in this round (true = right on the first tap).
class PickState {
  const PickState({
    required this.rounds,
    this.round = 0,
    this.index = 0,
    this.picked,
    this.results = const [],
    this.inSummary = false,
  });

  final List<List<PickItem>> rounds;
  final int round;
  final int index;
  final int? picked;
  final List<bool> results;
  final bool inSummary;

  int get roundSize => rounds.isEmpty ? 0 : rounds[round].length;
  PickItem? get item => rounds.isEmpty || inSummary ? null : rounds[round][index];
  Question? get question => item?.question;
  bool get kindIsWord => item?.kind == QuestionKind.wordToTranslation;

  ExercisePhase get phase {
    if (rounds.isEmpty) return const ExerciseNotEnough();
    if (inSummary) {
      return ExerciseSummary([
        for (var i = 0; i < results.length; i++)
          WordOutcome(
            rowId: rounds[round][i].question.rowId,
            word: rounds[round][i].word,
            result: results[i] ? 'Right' : 'Missed',
          ),
      ], hasNextRound: round + 1 < rounds.length);
    }
    return ExerciseRound(round, rounds.length);
  }

  PickState copyWith({int? round, int? index, int? picked, List<bool>? results, bool? inSummary, bool clearPicked = false}) =>
      PickState(
        rounds: rounds,
        round: round ?? this.round,
        index: index ?? this.index,
        picked: clearPicked ? null : (picked ?? this.picked),
        results: results ?? this.results,
        inSummary: inSummary ?? this.inSummary,
      );
}

const _kinds = [QuestionKind.wordToTranslation, QuestionKind.meaningToWord];

/// The pick-the-answer exercise of one group (learn-pick-the-answer). Nothing
/// is saved and nothing leaves the phone (D-04, AC-16, AC-18); the words come
/// from [exerciseWordsProvider]. Auto-disposed, so leaving the screen forgets
/// the round.
@riverpod
class PickTheAnswer extends _$PickTheAnswer {
  @override
  Future<PickState> build(String? sessionId, String groupId) async {
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    final pool = QuestionPool(group: words.group, others: words.others);
    // S-25: usable = a question exists for both kinds. Null never depends on
    // the Random, so a fixed seed finds the same words.
    final usable = <WordPair>[
      for (final word in words.group)
        if (_kinds.every((k) => buildQuestion(word, pool, k, Random(0)) != null)) word,
    ];
    final rounds = <List<PickItem>>[
      for (final round in splitRounds(usable, min: 3, max: 9))
        [
          for (var i = 0; i < round.length; i++)
            PickItem(
              word: round[i].word.trim(),
              kind: _kinds[i % 2],
              question: buildQuestion(round[i], pool, _kinds[i % 2], random)!,
            ),
        ],
    ];
    return PickState(rounds: rounds);
  }

  /// Retry after a failed load: read the words again.
  void retry() {
    ref.invalidate(exerciseWordsProvider(sessionId, groupId));
    ref.invalidateSelf();
  }

  /// The first tap on an option is final (D-17, AC-05, AC-06).
  void pick(int option) {
    final s = state.valueOrNull;
    if (s == null || s.item == null || s.picked != null) return;
    state = AsyncData(s.copyWith(
      picked: option,
      results: [...s.results, option == s.question!.rightIndex],
    ));
  }

  /// Next question, or the summary after the last (AC-07).
  void next() {
    final s = state.valueOrNull;
    if (s == null || s.item == null || s.picked == null) return;
    if (s.index + 1 < s.roundSize) {
      state = AsyncData(s.copyWith(index: s.index + 1, clearPicked: true));
    } else {
      state = AsyncData(s.copyWith(inSummary: true, clearPicked: true));
    }
  }

  /// "Next round" on the summary (AC-15): kind A again (S-29).
  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(s.copyWith(round: s.round + 1, index: 0, results: const [], inSummary: false, clearPicked: true));
  }
}
