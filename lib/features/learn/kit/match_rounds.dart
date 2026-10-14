import 'dart:math';

import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/models/word_pair.dart';
import 'exercise_phase.dart';
import 'match_board.dart';
import 'result_summary.dart';

/// Shared round code of the match exercises (S-41): cut-and-paste from
/// match-synonyms, names made neutral.

/// How long the last lock shows before the summary opens (S-36).
const matchSummaryDelay = Duration(milliseconds: 500);

/// A usable word with its answer in shown form (S-38).
class MatchPair {
  const MatchPair({required this.rowId, required this.word, required this.answer, required this.translation});

  final String rowId;
  final String word;
  final String answer;
  final String translation;
}

String _norm(String text) => text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The usable words of a match exercise (S-38, extends D-07), in group order:
/// a word needs an answer that does not hold the word itself, and neither the
/// word nor its answer may equal a word or answer already kept. The earlier
/// word always stays. [answers] are by rowId, already in shown form.
List<MatchPair> usableMatchPairs(List<WordPair> words, Map<String, String?> answers) {
  final keptWords = <String>{};
  final keptAnswers = <String>{};
  final usable = <MatchPair>[];
  for (final w in words) {
    final answer = answers[w.rowId]?.trim();
    final word = w.word.trim();
    if (answer == null || answer.isEmpty || word.isEmpty) continue;
    if (matchPlaces(answer, word).isNotEmpty) continue;
    final (nw, na) = (_norm(word), _norm(answer));
    if (nw == na || keptWords.contains(nw) || keptAnswers.contains(nw)) continue;
    if (keptAnswers.contains(na) || keptWords.contains(na)) continue;
    keptWords.add(nw);
    keptAnswers.add(na);
    usable.add(MatchPair(rowId: w.rowId, word: word, answer: answer, translation: w.translation.trim()));
  }
  return usable;
}

/// One board: the words in group order, their answers shuffled once (S-36).
class MatchRound {
  const MatchRound({required this.pairs, required this.left, required this.right});

  final List<MatchPair> pairs;
  final List<MatchItem> left;
  final List<MatchItem> right;
}

/// S-36: shuffled once; a shuffle equal to the left order moves its first
/// card to the end, so a board is never in order.
List<MatchItem> shuffledOutOfOrder(List<MatchItem> items, Random random) {
  final out = [...items]..shuffle(random);
  var same = true;
  for (var i = 0; i < out.length; i++) {
    if (out[i].id != items[i].id) same = false;
  }
  if (same && out.length > 1) out.add(out.removeAt(0));
  return out;
}

/// Where a match exercise stands (S-06, S-35): [links] (leftId → rightId, in
/// the order made) and [misses] (by rowId) are the current round's.
class MatchRoundsState {
  const MatchRoundsState({
    required this.rounds,
    this.notEnoughMessage,
    this.round = 0,
    this.links = const {},
    this.misses = const {},
    this.inSummary = false,
  });

  final List<MatchRound> rounds;
  final String? notEnoughMessage;
  final int round;
  final Map<String, String> links;
  final Map<String, int> misses;
  final bool inSummary;

  List<MatchItem> get left => rounds[round].left;
  List<MatchItem> get right => rounds[round].right;
  bool get roundDone => rounds.isNotEmpty && links.length == rounds[round].pairs.length;

  ExercisePhase get phase {
    if (rounds.isEmpty) return ExerciseNotEnough(notEnoughMessage);
    if (inSummary) {
      return ExerciseSummary([
        for (final p in rounds[round].pairs)
          WordOutcome(rowId: p.rowId, word: p.word, result: missesText(misses[p.rowId] ?? 0)),
      ], hasNextRound: round + 1 < rounds.length);
    }
    return ExerciseRound(round, rounds.length);
  }

  MatchRoundsState copyWith({int? round, Map<String, String>? links, Map<String, int>? misses, bool? inSummary}) =>
      MatchRoundsState(
        rounds: rounds,
        notEnoughMessage: notEnoughMessage,
        round: round ?? this.round,
        links: links ?? this.links,
        misses: misses ?? this.misses,
        inSummary: inSummary ?? this.inSummary,
      );
}
