import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import 'guess_my_word_notifier.dart';
import 'guess_my_word_page_body.dart';

/// Guess my word for one word group (learn-guess-my-word): the clues so far,
/// a grid of the round's words and the outcome of the current target
/// ([GuessMyWordPageBody]), inside the shared frame (S-30, S-52). State lives
/// in the notifier.
class GuessMyWordScreen extends ConsumerWidget {
  const GuessMyWordScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = guessMyWordProvider(collectionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Guess my word',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final counter = 'Word ${s.targetIndex + 1} of ${s.targets.length}';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GuessMyWordPageBody(
            header: round.count >= 2 ? 'Round ${round.index + 1} of ${round.count} · $counter' : counter,
            target: s.target!,
            level: s.level,
            grid: s.grid,
            greyed: s.greyed,
            points: s.points,
            revealed: s.revealed,
            onTap: notifier.tap,
            onNext: notifier.next,
          ),
        );
      },
    );
  }
}
