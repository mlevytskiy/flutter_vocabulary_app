import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/match_board.dart';
import '../kit/result_summary.dart';
import '../kit/split_rounds.dart';

part 'match_synonyms_notifier.g.dart';

/// The not-enough line once the Worker's answers leave fewer than 3 words (S-39).
const notEnoughSynonymsMessage = 'Not enough words with synonyms for this group';

/// How long the last lock shows before the summary opens (S-36, AC-08).
const matchSummaryDelay = Duration(milliseconds: 500);

/// A usable word with its synonym (S-38).
class SynonymPair {
  const SynonymPair({required this.rowId, required this.word, required this.synonym, required this.translation});

  final String rowId;
  final String word;
  final String synonym;
  final String translation;
}

String _norm(String text) => text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The usable words of match-synonyms (S-38, extends D-07), in group order:
/// a word needs a synonym that does not hold the word itself, and neither the
/// word nor its synonym may equal a word or synonym already kept. The earlier
/// word always stays.
List<SynonymPair> usableSynonymPairs(List<WordPair> words, Map<String, SynonymData?> answers) {
  final keptWords = <String>{};
  final keptAnswers = <String>{};
  final usable = <SynonymPair>[];
  for (final w in words) {
    final synonym = answers[w.rowId]?.synonym.trim();
    final word = w.word.trim();
    if (synonym == null || synonym.isEmpty || word.isEmpty) continue;
    if (matchPlaces(synonym, word).isNotEmpty) continue;
    final (nw, na) = (_norm(word), _norm(synonym));
    if (nw == na || keptWords.contains(nw) || keptAnswers.contains(nw)) continue;
    if (keptAnswers.contains(na) || keptWords.contains(na)) continue;
    keptWords.add(nw);
    keptAnswers.add(na);
    usable.add(SynonymPair(rowId: w.rowId, word: word, synonym: synonym, translation: w.translation.trim()));
  }
  return usable;
}

/// One board: the words in group order, their synonyms shuffled once (S-36).
class MatchRound {
  const MatchRound({required this.pairs, required this.left, required this.right});

  final List<SynonymPair> pairs;
  final List<MatchItem> left;
  final List<MatchItem> right;
}

/// Where match-synonyms stands (S-06, S-35): [links] (leftId → rightId, in
/// the order made) and [misses] (by rowId) are the current round's.
class MatchSynonymsState {
  const MatchSynonymsState({
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

  MatchSynonymsState copyWith({int? round, Map<String, String>? links, Map<String, int>? misses, bool? inSummary}) =>
      MatchSynonymsState(
        rounds: rounds,
        notEnoughMessage: notEnoughMessage,
        round: round ?? this.round,
        links: links ?? this.links,
        misses: misses ?? this.misses,
        inSummary: inSummary ?? this.inSummary,
      );
}

/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).
@riverpod
class MatchSynonyms extends _$MatchSynonyms {
  Timer? _summary;

  @override
  Future<MatchSynonymsState> build(String? sessionId, String groupId) async {
    ref.onDispose(() => _summary?.cancel());
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    final group = words.group;
    if (group.length < 3) return const MatchSynonymsState(rounds: []);
    final answers = await ref.read(learnApiServiceProvider).fetchData(LearnDataKind.synonym, [
      for (final w in group) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ]);
    final usable = usableSynonymPairs(group, answers);
    final rounds = <MatchRound>[
      for (final pairs in splitRounds(usable, min: 3, max: 6))
        MatchRound(
          pairs: pairs,
          left: [
            for (final p in pairs) MatchItem(id: p.rowId, text: cardText(p.word), hint: p.translation.isEmpty ? null : p.translation),
          ],
          right: _shuffled([for (final p in pairs) MatchItem(id: p.rowId, text: cardText(p.synonym))], random),
        ),
    ];
    return MatchSynonymsState(rounds: rounds, notEnoughMessage: rounds.isEmpty ? notEnoughSynonymsMessage : null);
  }

  /// S-36: shuffled once; a shuffle equal to the left order moves its first
  /// card to the end, so a board is never in order.
  static List<MatchItem> _shuffled(List<MatchItem> items, Random random) {
    final out = [...items]..shuffle(random);
    var same = true;
    for (var i = 0; i < out.length; i++) {
      if (out[i].id != items[i].id) same = false;
    }
    if (same && out.length > 1) out.add(out.removeAt(0));
    return out;
  }

  /// Retry after a failed load: read the words and ask the Worker again.
  void retry() {
    ref.invalidate(exerciseWordsProvider(sessionId, groupId));
    ref.invalidateSelf();
  }

  /// The board's question (S-35, S-38): right iff both ids are the word's
  /// rowId. A right pair is linked; a wrong one counts a miss on the left
  /// word. The last link opens the summary [matchSummaryDelay] later.
  bool pair(String leftId, String rightId) {
    final s = state.valueOrNull;
    if (s == null || s.rounds.isEmpty || s.inSummary || s.roundDone) return false;
    if (s.links.containsKey(leftId) || s.links.containsValue(rightId)) return false;
    if (!s.left.any((x) => x.id == leftId) || !s.right.any((x) => x.id == rightId)) return false;
    if (leftId != rightId) {
      state = AsyncData(s.copyWith(misses: {...s.misses, leftId: (s.misses[leftId] ?? 0) + 1}));
      return false;
    }
    final next = s.copyWith(links: {...s.links, leftId: rightId});
    state = AsyncData(next);
    if (next.roundDone) {
      _summary?.cancel();
      _summary = Timer(matchSummaryDelay, () {
        final now = state.valueOrNull;
        if (now != null && now.roundDone) state = AsyncData(now.copyWith(inSummary: true));
      });
    }
    return true;
  }

  /// "Next round" on the summary: a fresh board (AC-20).
  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(s.copyWith(round: s.round + 1, links: const {}, misses: const {}, inSummary: false));
  }
}
