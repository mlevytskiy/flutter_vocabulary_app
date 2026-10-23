import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import 'translate_sentences_notifier.dart';
import 'translate_sentences_page_body.dart';

/// The translation exam of one word group (learn-translate-sentences) inside
/// the shared frame (S-30): the Ukrainian sentence with the cue in bold, the
/// kit's exam field under it, and, once the word is final, the model
/// translation with the word in bold. The phase comes from the notifier.
class TranslateSentencesScreen extends ConsumerWidget {
  const TranslateSentencesScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = translateSentencesProvider(collectionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Translate sentences',
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
              TranslateSentencesPageBody(
                card: card,
                fieldKey: ValueKey('check-${s.round}-${card.rowId}'),
                onDone: notifier.done,
              ),
              if (s.result != null) ...[
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
