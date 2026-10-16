import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import '../kit/definition_text.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/match_board.dart';
import '../kit/match_rounds.dart';
import '../kit/split_rounds.dart';

part 'match_definitions_notifier.g.dart';

/// The not-enough line once the definitions leave fewer than 3 words (S-39).
const notEnoughDefinitionsMessage = 'Not enough words with definitions for this group';

/// The match-word-and-definition exercise of one group
/// (learn-match-definitions): a word's stored definition line first, else one
/// Worker call for the words without one (S-42); nothing saved (D-04).
/// Auto-disposed, so leaving the screen forgets the round (AC-22).
@riverpod
class MatchDefinitions extends _$MatchDefinitions {
  Timer? _summary;

  @override
  Future<MatchRoundsState> build(String? collectionId, String groupId) async {
    ref.onDispose(() => _summary?.cancel());
    final random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(collectionId, groupId).future);
    final group = words.group;
    if (group.length < 3) return const MatchRoundsState(rounds: []);
    // Stored line (S-40) first; a word with no stored line is asked (S-42).
    final answers = <String, String?>{};
    final asked = [
      for (final w in group)
        if (definitionText(w.definition).isEmpty) w,
    ];
    for (final w in group) {
      if (definitionText(w.definition).isNotEmpty) answers[w.rowId] = definitionCard(w.definition, w.word);
    }
    if (asked.isNotEmpty) {
      final fetched = await ref.read(learnApiServiceProvider).fetchData(LearnDataKind.definition, [
        for (final w in asked) (rowId: w.rowId, word: w.word.trim(), translation: w.translation.trim()),
      ]);
      for (final w in asked) {
        final text = fetched[w.rowId]?.definition;
        answers[w.rowId] = text == null ? null : definitionCard(text, w.word);
      }
    }
    final usable = usableMatchPairs(group, answers);
    final rounds = <MatchRound>[
      for (final pairs in splitRounds(usable, min: 3, max: 6))
        MatchRound(
          pairs: pairs,
          left: [for (final p in pairs) MatchItem(id: p.rowId, text: cardText(p.word))],
          // The answer is already card text (S-40); cutting twice could cut again.
          right: shuffledOutOfOrder([for (final p in pairs) MatchItem(id: p.rowId, text: p.answer)], random),
        ),
    ];
    return MatchRoundsState(rounds: rounds, notEnoughMessage: rounds.isEmpty ? notEnoughDefinitionsMessage : null);
  }

  /// Retry after a failed load: read the words and ask the Worker again.
  void retry() {
    ref.invalidate(exerciseWordsProvider(collectionId, groupId));
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

  /// "Next round" on the summary: a fresh board.
  void nextRound() {
    final s = state.valueOrNull;
    if (s == null || !s.inSummary || s.round + 1 >= s.rounds.length) return;
    state = AsyncData(s.copyWith(round: s.round + 1, links: const {}, misses: const {}, inSummary: false));
  }
}
