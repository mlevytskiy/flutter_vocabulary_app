import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/definition_text.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/result_summary.dart';
import '../kit/split_rounds.dart';
import '../kit/word_marks.dart';

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

final _usableText = RegExp(r'[\p{L}\p{N}]', unicode: true);
bool _usable(String clue) => _usableText.hasMatch(clue.replaceAll('___', ''));
String _norm(String text) => text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The guess-my-word exercise of one group (learn-guess-my-word): one Worker
/// call for kind `clues`, three masked clues per word (S-51), rounds, scores
/// (S-52). Auto-disposed, so leaving the screen forgets the round (AC-23).
@riverpod
class GuessMyWord extends _$GuessMyWord {
  Timer? _next;

  @override
  Future<GuessState> build(String? sessionId, String groupId) async {
    ref.onDispose(() => _next?.cancel());
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    // S-51: a word to learn with a word, a translation and a row id; the earlier of equal words stays.
    final seen = <String>{};
    final candidates = [
      for (final w in words.group)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty && seen.add(_norm(w.word))) w,
    ];
    if (candidates.length < 3) return const GuessState(rounds: []);
    final replies = await ref.read(learnApiServiceProvider).fetchData(LearnDataKind.clues, [
      for (final w in candidates) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ]);
    final usable = <GuessWord>[];
    for (final w in candidates) {
      final data = replies[w.rowId];
      if (data == null || data.clues.length != 3) continue;
      final word = w.word.trim();
      final c1 = maskWord(data.clues[0], word).trim();
      final c2 = maskWord(data.clues[1], word).trim();
      final c3 = definitionCard(w.definition, word) ?? maskWord(data.clues[2], word).trim();
      if (!_usable(c1) || !_usable(c2) || !_usable(c3)) continue;
      usable.add(GuessWord(rowId: w.rowId, word: word, translation: w.translation.trim(), clues: [c1, c2, c3]));
    }
    final rounds = <GuessRound>[
      for (final r in splitRounds(usable, min: 3, max: 9))
        GuessRound(words: r, grid: _shuffled(r, random), targets: _shuffled(r, random)),
    ];
    return GuessState(rounds: rounds, notEnoughMessage: rounds.isEmpty ? notEnoughCluesMessage : null);
  }

  static List<GuessWord> _shuffled(List<GuessWord> words, Random random) => [...words]..shuffle(random);

  /// Retry after a failed load: read the words and ask the Worker again.
  void retry() {
    ref.invalidate(exerciseWordsProvider(sessionId, groupId));
    ref.invalidateSelf();
  }

  /// A tap on a grid word (S-52). Found, greyed and revealed-round taps do nothing.
  void tap(String rowId) {
    final s = state.valueOrNull;
    final target = s?.target;
    if (s == null || target == null || s.locked || s.revealed) return;
    if (s.points.containsKey(rowId) || s.greyed.contains(rowId)) return;
    if (!s.grid.any((w) => w.rowId == rowId)) return;
    if (rowId == target.rowId) {
      state = AsyncData(s.copyWith(points: {...s.points, rowId: 4 - s.level}, locked: true));
      _next?.cancel();
      _next = Timer(guessNextDelay, _advance);
    } else if (s.level >= 3) {
      state = AsyncData(s.copyWith(
        greyed: {...s.greyed, rowId},
        points: {...s.points, target.rowId: 0},
        revealed: true,
      ));
    } else {
      state = AsyncData(s.copyWith(greyed: {...s.greyed, rowId}, level: s.level + 1));
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
