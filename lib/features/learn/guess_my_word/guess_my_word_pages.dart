import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/definition_text.dart';
import '../kit/split_rounds.dart';
import '../kit/word_marks.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'guess_my_word_notifier.dart';
import 'guess_my_word_page_body.dart';

final _usableText = RegExp(r'[\p{L}\p{N}]', unicode: true);
bool _usable(String clue) => _usableText.hasMatch(clue.replaceAll('___', ''));
String _norm(String text) => text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The words Guess my word may ask about (S-51): a word to learn with a
/// word, a translation and a row id; the earlier of equal words stays.
List<WordPair> guessCandidates(List<WordPair> group) {
  final seen = <String>{};
  return [
    for (final w in group)
      if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty && seen.add(_norm(w.word))) w,
  ];
}

/// The usable words with their three masked clues (S-51): one Worker call
/// for kind `clues`. A failed call throws [LearnApiException].
Future<List<GuessWord>> guessWords(List<WordPair> candidates, LearnApiService api) async {
  final replies = await api.fetchData(LearnDataKind.clues, [
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
  return usable;
}

List<GuessWord> _shuffled(List<GuessWord> words, Random random) => [...words]..shuffle(random);

/// The rounds of 3–9 words (S-52), the grid and target orders shuffled once.
List<GuessRound> guessRounds(List<GuessWord> usable, Random random) => <GuessRound>[
      for (final r in splitRounds(usable, min: 3, max: 9))
        GuessRound(words: r, grid: _shuffled(r, random), targets: _shuffled(r, random)),
    ];

/// A tap on a grid word (S-52): the state after it, or null when the tap does
/// nothing (no target, locked, revealed, found, greyed or not in the grid). A
/// right tap scores 4 − level and locks; a wrong one greys the word and shows
/// the next clue, or after the third clue reveals the target with 0 points.
GuessState? guessTap(GuessState s, String rowId) {
  final target = s.target;
  if (target == null || s.locked || s.revealed) return null;
  if (s.points.containsKey(rowId) || s.greyed.contains(rowId)) return null;
  if (!s.grid.any((w) => w.rowId == rowId)) return null;
  if (rowId == target.rowId) {
    return s.copyWith(points: {...s.points, rowId: 4 - s.level}, locked: true);
  } else if (s.level >= 3) {
    return s.copyWith(
      greyed: {...s.greyed, rowId},
      points: {...s.points, target.rowId: 0},
      revealed: true,
    );
  } else {
    return s.copyWith(greyed: {...s.greyed, rowId}, level: s.level + 1);
  }
}

/// Guess my word as learn pages (learn-redesign ADR-0003, AC-08): one step-1
/// page per usable word, its grid the words of its round as on the exercise
/// screen. Taps are checked as today ([guessTap]); the page reports through
/// `answer.done` — right when the word was found within the three clues,
/// wrong once it was shown (AC-10). Fewer than 3 words ask nothing; a failed
/// Worker call throws (AC-11).
Future<List<ExercisePage>> guessMyWordPages(PageInput input) async {
  final candidates = guessCandidates(input.words);
  if (candidates.length < 3) return const [];
  final usable = await guessWords(candidates, input.api);
  return [
    for (final round in guessRounds(usable, input.random))
      for (final target in round.targets)
        ExercisePage(
          exerciseId: 'guess-my-word',
          exerciseName: 'Guess my word',
          step: 1,
          rowIds: [target.rowId],
          body: (context, answer) => _GuessPage(
            key: ValueKey('guess-my-word-${target.rowId}'),
            round: GuessRound(words: round.words, grid: round.grid, targets: [target]),
            answer: answer,
          ),
        ),
  ];
}

/// One target of Guess my word on a learn page: the exercise's state with a
/// single target, so the screen's rules and body draw it.
class _GuessPage extends StatefulWidget {
  const _GuessPage({super.key, required this.round, required this.answer});

  final GuessRound round;
  final PageAnswer answer;

  @override
  State<_GuessPage> createState() => _GuessPageState();
}

class _GuessPageState extends State<_GuessPage> {
  late GuessState _state = GuessState(rounds: [widget.round]);

  void _tap(String rowId) {
    final next = guessTap(_state, rowId);
    if (next == null) return;
    setState(() => _state = next);
    final target = widget.round.targets.single.rowId;
    final points = next.points[target];
    if (points != null) widget.answer.done({target: points > 0});
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return GuessMyWordPageBody(
      target: s.target!,
      level: s.level,
      grid: s.grid,
      greyed: s.greyed,
      points: s.points,
      revealed: s.revealed,
      onTap: _tap,
    );
  }
}
