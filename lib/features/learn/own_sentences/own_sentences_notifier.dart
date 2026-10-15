import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../kit/check_verdict.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/result_summary.dart';
import '../kit/sentence_check.dart';
import '../kit/split_rounds.dart';

part 'own_sentences_notifier.g.dart';

/// The frozen exercise id this exam records its word results under (S-02, S-55).
const ownExerciseId = 'own-sentences';

/// One word's card: only the word is shown; the translation is for the check.
class OwnCard {
  const OwnCard({required this.rowId, required this.word, required this.translation});

  final String rowId;
  final String word;
  final String translation;
}

/// S-58, S-60: the detail line of a word in the summary. Pure.
String ownDetail(SentenceResult result) {
  if (result.outcome == SentenceOutcome.skipped) return 'Skipped';
  final verdict = result.verdict;
  if (result.outcome == SentenceOutcome.fixed && verdict is CheckFixed && verdict.fixed.trim().isNotEmpty) {
    return 'Answer: ${verdict.fixed} · Yours: ${result.sentence}';
  }
  return 'Yours: ${result.sentence}';
}

/// Where the exam stands: [rounds] of cards (each shuffled once), the current
/// [round] and card [index], the current word's final [result] and the final
/// results of this round's words already left.
class OwnState {
  const OwnState({
    required this.rounds,
    this.round = 0,
    this.index = 0,
    this.result,
    this.results = const [],
  });

  final List<List<OwnCard>> rounds;
  final int round;
  final int index;
  final SentenceResult? result;
  final List<SentenceResult> results;

  List<OwnCard> get cards => rounds.isEmpty ? const [] : rounds[round];
  bool get inSummary => rounds.isNotEmpty && index >= cards.length;
  OwnCard? get card => rounds.isEmpty || inSummary ? null : cards[index];

  ExercisePhase get phase {
    if (rounds.isEmpty) return const ExerciseNotEnough();
    if (!inSummary) return ExerciseRound(round, rounds.length);
    final known = results.where((r) => r.outcome == SentenceOutcome.right).length;
    return ExerciseSummary(
      [
        for (var i = 0; i < cards.length; i++)
          WordOutcome(
            rowId: cards[i].rowId,
            word: cards[i].word,
            result: examSummaryText(results[i].outcome),
            detail: ownDetail(results[i]),
          ),
      ],
      hasNextRound: round + 1 < rounds.length,
      heading: examHeading(known, cards.length),
    );
  }
}

/// The own-sentences exam of one group (learn-own-sentences). No Worker data:
/// only the group's words are read. Each final word records its result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
@riverpod
class OwnSentences extends _$OwnSentences {
  @override
  Future<OwnState> build(String? sessionId, String groupId) async {
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    final usable = <OwnCard>[
      for (final WordPair w in words.group)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty)
          OwnCard(rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ];
    if (usable.length < 3) return const OwnState(rounds: []);
    return OwnState(rounds: [for (final r in splitRounds(usable, min: 3, max: 5)) _shuffled(r, random)]);
  }

  List<OwnCard> _shuffled(List<OwnCard> round, Random random) => [...round]..shuffle(random);

  void retry() {
    ref.invalidate(exerciseWordsProvider(sessionId, groupId));
    ref.invalidateSelf();
  }

  /// The current word's final result from the field. It is stored and, in the
  /// same step, recorded (S-55): once per word, never awaited, nothing for
  /// "not checked". A second call does nothing.
  void done(SentenceResult result) {
    final s = state.valueOrNull;
    final card = s?.card;
    if (s == null || card == null || s.result != null) return;
    state = AsyncData(OwnState(rounds: s.rounds, round: s.round, index: s.index, result: result, results: s.results));
    final label = examLabel(result.outcome);
    if (label == null) return;
    unawaited(ref.read(examResultSinkProvider).record(
          sessionId: sessionId,
          rowId: card.rowId,
          exerciseId: ownExerciseId,
          label: label,
        ));
  }

  /// Leaves a final word for the next card, or the summary. Records nothing.
  void next() {
    final s = state.valueOrNull;
    final result = s?.result;
    if (s == null || result == null) return;
    state = AsyncData(OwnState(rounds: s.rounds, round: s.round, index: s.index + 1, results: [...s.results, result]));
  }

  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(OwnState(rounds: s.rounds, round: s.round + 1));
  }
}
