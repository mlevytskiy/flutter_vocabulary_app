import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/result_summary.dart';
import 'guess_my_word_pages.dart';

part 'guess_my_word_notifier.g.dart';

/// The not-enough line once the clues leave fewer than 3 words (S-51).
const notEnoughCluesMessage = 'Not enough words with clues for this group';

/// The pause after a right tap before the next target (S-52).
const guessNextDelay = Duration(milliseconds: 600);

/// One word with its three shown clues (S-51): already masked.
class GuessWord {
  const GuessWord({required this.rowId, required this.word, required this.translation, required this.clues});

  final String rowId;
  final String word;
  final String translation;
  final List<String> clues;
}

/// One round: [words] in group order, the [grid] order and the [targets]
/// order, both shuffled once when the exercise opens (S-52).
class GuessRound {
  const GuessRound({required this.words, required this.grid, required this.targets});

  final List<GuessWord> words;
  final List<GuessWord> grid;
  final List<GuessWord> targets;
}

/// Where guess-my-word stands: the current [round], the [targetIndex], the
/// clue [level] (1..3), the words [greyed] for this target, the [points] of
/// every finished target (0 = shown as the answer), whether the answer is
/// [revealed] and a right tap is [locked] for the pause. Nothing is saved.
class GuessState {
  const GuessState({
    required this.rounds,
    this.notEnoughMessage,
    this.round = 0,
    this.targetIndex = 0,
    this.level = 1,
    this.greyed = const {},
    this.points = const {},
    this.revealed = false,
    this.locked = false,
  });

  final List<GuessRound> rounds;
  final String? notEnoughMessage;
  final int round;
  final int targetIndex;
  final int level;
  final Set<String> greyed;
  final Map<String, int> points;
  final bool revealed;
  final bool locked;

  GuessRound? get current => rounds.isEmpty ? null : rounds[round];
  List<GuessWord> get grid => current?.grid ?? const [];
  List<GuessWord> get targets => current?.targets ?? const [];
  bool get inSummary => rounds.isNotEmpty && targetIndex >= targets.length;
  GuessWord? get target => rounds.isEmpty || inSummary ? null : targets[targetIndex];

  GuessState copyWith({
    int? round,
    int? targetIndex,
    int? level,
    Set<String>? greyed,
    Map<String, int>? points,
    bool? revealed,
    bool? locked,
  }) =>
      GuessState(
        rounds: rounds,
        notEnoughMessage: notEnoughMessage,
        round: round ?? this.round,
        targetIndex: targetIndex ?? this.targetIndex,
        level: level ?? this.level,
        greyed: greyed ?? this.greyed,
        points: points ?? this.points,
        revealed: revealed ?? this.revealed,
        locked: locked ?? this.locked,
      );

  ExercisePhase get phase {
    if (rounds.isEmpty) return ExerciseNotEnough(notEnoughMessage);
    if (!inSummary) return ExerciseRound(round, rounds.length);
    final words = current!.words;
    return ExerciseSummary(
      [
        for (final w in words) WordOutcome(rowId: w.rowId, word: w.word, result: pointsText(points[w.rowId] ?? 0)),
      ],
      hasNextRound: round + 1 < rounds.length,
      heading: 'Score: ${words.fold<int>(0, (a, w) => a + (points[w.rowId] ?? 0))} of ${3 * words.length}',
    );
  }
}

/// "3 points" / "2 points" / "1 point" / "Not found" (summary results).
String pointsText(int p) => p <= 0 ? 'Not found' : (p == 1 ? '1 point' : '$p points');

/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
@riverpod
class GuessMyWord extends _$GuessMyWord {
  Timer? _next;

  @override
  Future<GuessState> build(String? collectionId, String groupId) async {
    ref.onDispose(() => _next?.cancel());
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(collectionId, groupId).future);
    final candidates = guessCandidates(words.group);
    if (candidates.length < 3) return const GuessState(rounds: []);
    final usable = await guessWords(candidates, ref.read(learnApiServiceProvider));
    final rounds = guessRounds(usable, random);
    return GuessState(rounds: rounds, notEnoughMessage: rounds.isEmpty ? notEnoughCluesMessage : null);
  }

  /// Retry after a failed load: read the words and ask the Worker again.
  void retry() {
    ref.invalidate(exerciseWordsProvider(collectionId, groupId));
    ref.invalidateSelf();
  }

  /// A tap on a grid word (S-52). Found, greyed and revealed-round taps do nothing.
  void tap(String rowId) {
    final s = state.valueOrNull;
    if (s == null) return;
    final next = guessTap(s, rowId);
    if (next == null) return;
    state = AsyncData(next);
    if (next.locked) {
      _next?.cancel();
      _next = Timer(guessNextDelay, _advance);
    }
  }

  /// "Next" after the answer was shown.
  void next() {
    final s = state.valueOrNull;
    if (s == null || !s.revealed) return;
    _advance();
  }

  void _advance() {
    final s = state.valueOrNull;
    if (s == null || s.target == null) return;
    state = AsyncData(s.copyWith(targetIndex: s.targetIndex + 1, level: 1, greyed: const {}, revealed: false, locked: false));
  }

  /// "Next round" on the summary: a fresh round.
  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(s.copyWith(round: s.round + 1, targetIndex: 0, level: 1, greyed: const {}, points: const {}));
  }
}
