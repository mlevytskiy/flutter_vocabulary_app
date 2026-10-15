import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/learn_api_service.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/sentence_check.dart';
import 'own_sentences_notifier.dart';

/// The own-sentences exam of one word group (learn-own-sentences) inside the
/// shared frame (S-30): the word and one prompt, then the kit's exam field.
/// Nothing else is shown on the card (D-34). The phase comes from the notifier.
class OwnSentencesScreen extends ConsumerWidget {
  const OwnSentencesScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ownSentencesProvider(sessionId, groupId);
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
        final style = Theme.of(context).textTheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Word ${s.index + 1} of ${s.cards.length}'),
              const SizedBox(height: 16),
              Text(card.word, key: const ValueKey('own-word'), style: style.headlineMedium),
              const SizedBox(height: 8),
              Text('Write a sentence with “${card.word}”.'),
              const SizedBox(height: 16),
              SentenceCheckField(
                key: ValueKey('check-${s.round}-${card.rowId}'),
                word: card.word,
                translation: card.translation,
                task: LearnCheckTask.own,
                mode: SentenceCheckMode.exam,
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
