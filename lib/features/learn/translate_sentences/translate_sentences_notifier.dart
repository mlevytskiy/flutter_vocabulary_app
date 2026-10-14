import 'dart:async';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/result_summary.dart';
import '../kit/sentence_check.dart';
import '../kit/split_rounds.dart';
import '../kit/word_marks.dart';

part 'translate_sentences_notifier.g.dart';

/// The frozen exercise id this exam records its word results under (S-02, S-55).
const translateExerciseId = 'translate-sentences';

/// One word's card: the Worker's kind `translate` for the word (S-15).
class TranslateCard {
  const TranslateCard({
    required this.rowId,
    required this.word,
    required this.translation,
    required this.source,
    required this.cue,
    required this.model,
  });

  final String rowId;
  final String word;
  final String translation;

  /// The Ukrainian sentence; [cue] is an exact part of it (S-57).
  final String source;
  final String cue;

  /// The English model translation; holds [word] exactly once (S-57).
  final String model;
}

/// [source] with the first occurrence of [cue] in bold (D-34). Pure.
List<TextSpan> cueSpans(String source, String cue) {
  final at = cue.isEmpty ? -1 : source.indexOf(cue);
  if (at < 0) return [TextSpan(text: source)];
  return [
    if (at > 0) TextSpan(text: source.substring(0, at)),
    TextSpan(text: cue, style: const TextStyle(fontWeight: FontWeight.bold)),
    if (at + cue.length < source.length) TextSpan(text: source.substring(at + cue.length)),
  ];
}

/// S-58: the detail line of a word in the summary of a sentence exam. Pure.
String translateDetail(TranslateCard card, SentenceResult result) => switch (result.outcome) {
      SentenceOutcome.right => 'Yours: ${result.sentence}',
      SentenceOutcome.skipped => 'Answer: ${card.model} · Skipped',
      SentenceOutcome.fixed || SentenceOutcome.notChecked => 'Answer: ${card.model} · Yours: ${result.sentence}',
    };

/// Where the exam stands: [rounds] of cards (each shuffled once), the current
/// [round] and card [index], the current word's final [result] and the final
/// results of this round's words already left.
class TranslateState {
  const TranslateState({
    required this.rounds,
    this.round = 0,
    this.index = 0,
    this.result,
    this.results = const [],
  });

  final List<List<TranslateCard>> rounds;
  final int round;
  final int index;
  final SentenceResult? result;
  final List<SentenceResult> results;

  List<TranslateCard> get cards => rounds.isEmpty ? const [] : rounds[round];
  bool get inSummary => rounds.isNotEmpty && index >= cards.length;
  TranslateCard? get card => rounds.isEmpty || inSummary ? null : cards[index];

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
            detail: translateDetail(cards[i], results[i]),
          ),
      ],
      hasNextRound: round + 1 < rounds.length,
      heading: examHeading(known, cards.length),
    );
  }
}

/// The translation exam of one group (learn-translate-sentences). Each final
/// word records its result through [examResultSinkProvider] at once (S-55);
/// nothing else is saved. Auto-disposed, so leaving forgets the exam.
@riverpod
class TranslateSentences extends _$TranslateSentences {
  @override
  Future<TranslateState> build(String? sessionId, String groupId) async {
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    final candidates = <WordPair>[
      for (final w in words.group)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty) w,
    ];
    if (candidates.length < 3) return const TranslateState(rounds: []);
    final replies = await ref.read(learnApiServiceProvider).fetchData(LearnDataKind.translate, [
      for (final w in candidates) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ]);
    final groupWords = [for (final w in words.group) if (w.word.trim().isNotEmpty) w.word.trim()];
    final cards = <TranslateCard>[];
    for (final w in candidates) {
      final data = replies[w.rowId];
      final word = w.word.trim();
      if (data == null || data.cue.isEmpty || !data.source.contains(data.cue)) continue;
      if (!holdsWordOnce(data.model, word)) continue;
      // S-57: no English word of the group may show on the card.
      if (groupWords.any((g) => matchPlaces(data.source, g).isNotEmpty)) continue;
      cards.add(TranslateCard(
        rowId: w.rowId,
        word: word,
        translation: w.translation.trim(),
        source: data.source,
        cue: data.cue,
        model: data.model,
      ));
    }
    return TranslateState(rounds: [for (final r in splitRounds(cards, min: 3, max: 5)) _shuffled(r, random)]);
  }

  List<TranslateCard> _shuffled(List<TranslateCard> round, Random random) => [...round]..shuffle(random);

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
    state = AsyncData(TranslateState(rounds: s.rounds, round: s.round, index: s.index, result: result, results: s.results));
    final label = examLabel(result.outcome);
    if (label == null) return;
    unawaited(ref.read(examResultSinkProvider).record(
          sessionId: sessionId,
          rowId: card.rowId,
          exerciseId: translateExerciseId,
          label: label,
        ));
  }

  /// Leaves a final word for the next card, or the summary. Records nothing.
  void next() {
    final s = state.valueOrNull;
    final result = s?.result;
    if (s == null || result == null) return;
    state = AsyncData(TranslateState(rounds: s.rounds, round: s.round, index: s.index + 1, results: [...s.results, result]));
  }

  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(TranslateState(rounds: s.rounds, round: s.round + 1));
  }
}
