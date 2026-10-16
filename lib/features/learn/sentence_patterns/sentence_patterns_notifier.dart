import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_words.dart';
import '../kit/result_summary.dart';
import '../kit/sentence_check.dart';
import '../kit/split_rounds.dart';
import '../kit/word_marks.dart';

part 'sentence_patterns_notifier.g.dart';

/// One word's pattern card: the Worker's kind `pattern` for the word (S-15).
class PatternCard {
  const PatternCard({
    required this.rowId,
    required this.word,
    required this.translation,
    required this.sentence,
    required this.pattern,
    required this.usage,
  });

  final String rowId;
  final String word;
  final String translation;

  /// Holds [word] exactly once (S-50), shown with it in bold.
  final String sentence;
  final String pattern;
  final String usage;
}

/// Where sentence-patterns stands: [rounds] of cards in group order, the
/// current [round] and card [index], whether "My turn" was tapped ([writing])
/// and the current word's final [result]. Nothing is saved.
class PatternsState {
  const PatternsState({
    required this.rounds,
    this.round = 0,
    this.index = 0,
    this.writing = false,
    this.result,
    this.results = const [],
  });

  final List<List<PatternCard>> rounds;
  final int round;
  final int index;
  final bool writing;
  final SentenceResult? result;

  /// The final results of the cards of this round already left, in order.
  final List<SentenceResult> results;

  List<PatternCard> get cards => rounds.isEmpty ? const [] : rounds[round];
  bool get inSummary => rounds.isNotEmpty && index >= cards.length;
  PatternCard? get card => rounds.isEmpty || inSummary ? null : cards[index];

  ExercisePhase get phase {
    if (rounds.isEmpty) return const ExerciseNotEnough();
    if (inSummary) {
      return ExerciseSummary(
        [
          for (var i = 0; i < cards.length; i++)
            WordOutcome(rowId: cards[i].rowId, word: cards[i].word, result: practiceLabel(results[i].outcome)),
        ],
        hasNextRound: round + 1 < rounds.length,
      );
    }
    return ExerciseRound(round, rounds.length);
  }
}

@riverpod
class SentencePatterns extends _$SentencePatterns {
  @override
  Future<PatternsState> build(String? collectionId, String groupId) async {
    final words = await ref.watch(exerciseWordsProvider(collectionId, groupId).future);
    // S-50: a word to learn with a word and a translation is a candidate.
    final candidates = <WordPair>[
      for (final w in words.group)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty) w,
    ];
    if (candidates.length < 3) return const PatternsState(rounds: []);
    final replies = await ref.read(learnApiServiceProvider).fetchData(LearnDataKind.pattern, [
      for (final w in candidates) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ]);
    final cards = <PatternCard>[];
    for (final w in candidates) {
      final data = replies[w.rowId];
      final word = w.word.trim();
      if (data == null || !holdsWordOnce(data.sentence, word)) continue;
      cards.add(PatternCard(
        rowId: w.rowId,
        word: word,
        translation: w.translation.trim(),
        sentence: data.sentence,
        pattern: data.pattern,
        usage: data.usage,
      ));
    }
    return PatternsState(rounds: splitRounds(cards, min: 3, max: 9));
  }

  void retry() {
    ref.invalidate(exerciseWordsProvider(collectionId, groupId));
    ref.invalidateSelf();
  }

  /// "My turn": the field opens under the card.
  void startWriting() {
    final s = state.valueOrNull;
    if (s == null || s.card == null || s.writing) return;
    state = AsyncData(PatternsState(rounds: s.rounds, round: s.round, index: s.index, writing: true, results: s.results));
  }

  /// The word's final result from the field; a second call does nothing.
  void done(SentenceResult result) {
    final s = state.valueOrNull;
    if (s == null || s.card == null || !s.writing || s.result != null) return;
    state = AsyncData(PatternsState(
        rounds: s.rounds, round: s.round, index: s.index, writing: true, result: result, results: s.results));
  }

  /// Leaves a final word for the next card, or the summary.
  void next() {
    final s = state.valueOrNull;
    final result = s?.result;
    if (s == null || result == null) return;
    state = AsyncData(PatternsState(rounds: s.rounds, round: s.round, index: s.index + 1, results: [...s.results, result]));
  }

  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(PatternsState(rounds: s.rounds, round: s.round + 1));
  }
}
