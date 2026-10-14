import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/match_board.dart';
import 'match_synonyms_notifier.dart';

/// Match synonyms for one word group (learn-match-synonyms): the kit's
/// [MatchBoard] inside the shared frame (S-30, S-35). The phase, links and
/// misses come from the notifier; this widget draws only the round body.
class MatchSynonymsScreen extends ConsumerWidget {
  const MatchSynonymsScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = matchSynonymsProvider(sessionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Match synonyms',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (round.count >= 2) ...[
                    Text('Round ${round.index + 1} of ${round.count}'),
                    const SizedBox(height: 8),
                  ],
                  const Text('Tap a word, then its synonym'),
                ],
              ),
            ),
            Expanded(
              child: MatchBoard(
                key: ValueKey('match-round-${round.index}'),
                left: s.left,
                right: s.right,
                links: s.links,
                onPair: notifier.pair,
              ),
            ),
          ],
        );
      },
    );
  }
}
