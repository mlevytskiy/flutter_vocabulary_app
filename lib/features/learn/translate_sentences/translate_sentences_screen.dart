import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/learn_api_service.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/sentence_check.dart';
import '../kit/word_marks.dart';
import 'translate_sentences_notifier.dart';

/// The translation exam of one word group (learn-translate-sentences) inside
/// the shared frame (S-30): the Ukrainian sentence with the cue in bold, the
/// kit's exam field under it, and, once the word is final, the model
/// translation with the word in bold. The phase comes from the notifier.
class TranslateSentencesScreen extends ConsumerWidget {
  const TranslateSentencesScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = translateSentencesProvider(sessionId, groupId);
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
        final style = Theme.of(context).textTheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Word ${s.index + 1} of ${s.cards.length}'),
              const SizedBox(height: 16),
              const Text('Translate into English.'),
              const SizedBox(height: 8),
              Text.rich(
                key: const ValueKey('translate-source'),
                TextSpan(children: cueSpans(card.source, card.cue)),
                style: style.titleMedium,
              ),
              const SizedBox(height: 16),
              SentenceCheckField(
                key: ValueKey('check-${s.round}-${card.rowId}'),
                word: card.word,
                translation: card.translation,
                task: LearnCheckTask.translate,
                extra: card.source,
                mode: SentenceCheckMode.exam,
                onDone: notifier.done,
              ),
              if (s.result != null) ...[
                const SizedBox(height: 16),
                const Text('Model translation:'),
                Text.rich(
                  key: const ValueKey('translate-model'),
                  TextSpan(children: boldWord(card.model, card.word)),
                ),
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
