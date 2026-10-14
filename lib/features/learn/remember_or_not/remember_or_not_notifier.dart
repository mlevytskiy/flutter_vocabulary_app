import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../kit/example_line.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/result_summary.dart';
import '../kit/split_rounds.dart';
import '../kit/word_marks.dart';

part 'remember_or_not_notifier.g.dart';

class FlashCard {
  const FlashCard({
    required this.rowId,
    required this.word,
    required this.front,
    required this.translation,
    this.example,
  });

  final String rowId;
  final String word;
  final String front;
  final String translation;
  final String? example;
}

final _letter = RegExp(r'\p{L}', unicode: true);

String? _maskedWithLetters(String text, String word) {
  final masked = maskWord(text.trim(), word);
  return masked.replaceAll('___', '').contains(_letter) ? masked : null;
}

/// The front of a card: the masked definition, else the masked translation
/// (D-08, D-16); null when neither keeps a letter, so the word is not usable.
String? frontFor(WordPair w) {
  final word = w.word.trim();
  if (word.isEmpty) return null;
  return _maskedWithLetters(w.definition, word) ?? _maskedWithLetters(w.translation, word);
}

class RememberState {
  const RememberState({
    required this.rounds,
    required this.queue,
    this.round = 0,
    this.flipped = false,
    this.repeated = const {},
    this.results = const {},
    this.shown = 0,
  });

  final List<List<FlashCard>> rounds;

  /// Indices (into the current round) still to show; the head is the current card.
  final List<int> queue;
  final int round;
  final bool flipped;

  /// Cards put back once; their next showing is the second.
  final Set<int> repeated;
  final Map<int, String> results;

  /// Cards shown before the current one in this round, put-back showings included.
  final int shown;

  static const remembered = 'Remembered';
  static const afterRepeat = 'Remembered after repeat';
  static const notYet = 'Not yet';

  List<FlashCard> get cards => rounds.isEmpty ? const [] : rounds[round];
  bool get inSummary => rounds.isNotEmpty && queue.isEmpty;
  FlashCard? get card => rounds.isEmpty || queue.isEmpty ? null : cards[queue.first];
  bool get secondShowing => queue.isNotEmpty && repeated.contains(queue.first);
  int get position => shown + 1;
  int get total => cards.length + repeated.length;

  ExercisePhase get phase {
    if (rounds.isEmpty) return const ExerciseNotEnough();
    if (inSummary) {
      final counts = {remembered: 0, afterRepeat: 0, notYet: 0};
      for (final r in results.values) {
        counts[r] = counts[r]! + 1;
      }
      return ExerciseSummary(
        [
          for (var i = 0; i < cards.length; i++)
            WordOutcome(rowId: cards[i].rowId, word: cards[i].word, result: results[i] ?? notYet),
        ],
        hasNextRound: round + 1 < rounds.length,
        heading: '${counts[remembered]} remembered, ${counts[afterRepeat]} after repeat, ${counts[notYet]} not yet',
      );
    }
    return ExerciseRound(round, rounds.length);
  }

  RememberState copyWith({
    List<int>? queue,
    int? round,
    bool? flipped,
    Set<int>? repeated,
    Map<int, String>? results,
    int? shown,
  }) =>
      RememberState(
        rounds: rounds,
        queue: queue ?? this.queue,
        round: round ?? this.round,
        flipped: flipped ?? this.flipped,
        repeated: repeated ?? this.repeated,
        results: results ?? this.results,
        shown: shown ?? this.shown,
      );
}

@riverpod
class RememberOrNot extends _$RememberOrNot {
  @override
  Future<RememberState> build(String? sessionId, String groupId) async {
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    final dialogues = await ref.watch(exerciseDialoguesProvider(sessionId).future);
    final usable = <FlashCard>[
      for (final w in words.group)
        if (frontFor(w) case final front?)
          FlashCard(
            rowId: w.rowId,
            word: w.word.trim(),
            front: front,
            translation: w.translation.trim(),
            example: exampleLineFor(w, dialogues),
          ),
    ];
    final rounds = [
      for (final r in splitRounds(usable, min: 3, max: 9)) ([...r]..shuffle(random)),
    ];
    return RememberState(rounds: rounds, queue: rounds.isEmpty ? const [] : _all(rounds.first));
  }

  List<int> _all(List<FlashCard> cards) => [for (var i = 0; i < cards.length; i++) i];

  void retry() {
    ref.invalidate(exerciseWordsProvider(sessionId, groupId));
    ref.invalidate(exerciseDialoguesProvider(sessionId));
    ref.invalidateSelf();
  }

  void flip() {
    final s = state.valueOrNull;
    if (s == null || s.card == null || s.flipped) return;
    state = AsyncData(s.copyWith(flipped: true));
  }

  /// Rates the card on its back: [remembered] true is "Remembered" / "Got it".
  void rate(bool remembered) {
    final s = state.valueOrNull;
    if (s == null || s.card == null || !s.flipped) return;
    final current = s.queue.first;
    final rest = s.queue.sublist(1);
    if (!remembered && !s.secondShowing) {
      state = AsyncData(s.copyWith(
        queue: [...rest, current],
        repeated: {...s.repeated, current},
        flipped: false,
        shown: s.shown + 1,
      ));
      return;
    }
    final result = !remembered
        ? RememberState.notYet
        : s.secondShowing
            ? RememberState.afterRepeat
            : RememberState.remembered;
    state = AsyncData(s.copyWith(
      queue: rest,
      results: {...s.results, current: result},
      flipped: false,
      shown: s.shown + 1,
    ));
  }

  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(RememberState(
      rounds: s.rounds,
      round: s.round + 1,
      queue: _all(s.rounds[s.round + 1]),
    ));
  }
}
