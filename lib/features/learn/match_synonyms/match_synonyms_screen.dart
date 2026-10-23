import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import 'match_synonyms_notifier.dart';
import 'match_synonyms_page_body.dart';

/// Match synonyms for one word group (learn-match-synonyms): the kit's board as
/// [MatchSynonymsPageBody] inside the shared frame (S-30, S-35). The phase, links and
/// misses come from the notifier; this widget draws only the round body.
class MatchSynonymsScreen extends ConsumerWidget {
  const MatchSynonymsScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = matchSynonymsProvider(collectionId, groupId);
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
        return MatchSynonymsPageBody(
          roundLabel: round.count >= 2 ? 'Round ${round.index + 1} of ${round.count}' : null,
          boardKey: ValueKey('match-round-${round.index}'),
          left: s.left,
          right: s.right,
          links: s.links,
          onPair: notifier.pair,
        );
      },
    );
  }
}
