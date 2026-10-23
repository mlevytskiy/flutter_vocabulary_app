import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/sentence_check.dart';
import 'own_sentences_notifier.dart';
import 'own_sentences_page_body.dart';

/// The own-sentences exam of one word group (learn-own-sentences) inside the
/// shared frame (S-30): the word and one prompt, then the kit's exam field.
/// Nothing else is shown on the card (D-34). The phase comes from the notifier.
class OwnSentencesScreen extends ConsumerWidget {
  const OwnSentencesScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ownSentencesProvider(collectionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Make your own sentences',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final card = s.card!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Word ${s.index + 1} of ${s.cards.length}'),
              const SizedBox(height: 16),
              OwnSentencesPageBody(
                card: card,
                fieldKey: ValueKey('check-${s.round}-${card.rowId}'),
                onDone: notifier.done,
              ),
              if (s.result != null) ...[
                if (s.result!.outcome == SentenceOutcome.skipped || s.result!.outcome == SentenceOutcome.notChecked) ...[
                  const SizedBox(height: 8),
                  Text(s.result!.outcome == SentenceOutcome.skipped ? 'Skipped' : 'Not checked'),
                ],
                const SizedBox(height: 16),
                ElevatedButton(onPressed: notifier.next, child: const Text('Next')),
              ],
            ],
          ),
        );
      },
    );
  }
}
