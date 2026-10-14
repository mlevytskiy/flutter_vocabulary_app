import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/match_board.dart';
import '../kit/match_rounds.dart';
import '../kit/split_rounds.dart';

part 'match_synonyms_notifier.g.dart';

/// The not-enough line once the Worker's answers leave fewer than 3 words (S-39).
const notEnoughSynonymsMessage = 'Not enough words with synonyms for this group';

/// The match-synonyms exercise of one group (learn-match-synonyms): one
/// Worker call for the whole group when it opens (S-39), nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-21).
@riverpod
class MatchSynonyms extends _$MatchSynonyms {
  Timer? _summary;

  @override
  Future<MatchRoundsState> build(String? sessionId, String groupId) async {
    ref.onDispose(() => _summary?.cancel());
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    final group = words.group;
    if (group.length < 3) return const MatchRoundsState(rounds: []);
    final answers = await ref.read(learnApiServiceProvider).fetchData(LearnDataKind.synonym, [
      for (final w in group) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
    ]);
    final usable = usableMatchPairs(group, {for (final e in answers.entries) e.key: e.value?.synonym});
    final rounds = <MatchRound>[
      for (final pairs in splitRounds(usable, min: 3, max: 6))
        MatchRound(
          pairs: pairs,
          left: [
            for (final p in pairs) MatchItem(id: p.rowId, text: cardText(p.word), hint: p.translation.isEmpty ? null : p.translation),
          ],
          right: shuffledOutOfOrder([for (final p in pairs) MatchItem(id: p.rowId, text: cardText(p.answer))], random),
        ),
    ];
    return MatchRoundsState(rounds: rounds, notEnoughMessage: rounds.isEmpty ? notEnoughSynonymsMessage : null);
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
