import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/choice_options.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import 'pick_the_answer_notifier.dart';

/// Pick the right answer for one word group (learn-pick-the-answer): one
/// question at a time with four options inside the shared frame (S-30). The
/// phase comes from the notifier; this widget draws only the question body.
class PickTheAnswerScreen extends ConsumerWidget {
  const PickTheAnswerScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = pickTheAnswerProvider(sessionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Pick the right answer',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final question = s.question!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Question ${s.index + 1} of ${s.roundSize}'),
              const SizedBox(height: 8),
              Text(s.kindIsWord ? 'Pick the translation' : 'Pick the word'),
              const SizedBox(height: 16),
              Text(question.prompt, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              ChoiceOptions(
                question: question,
                picked: s.picked,
                reveal: true,
                onPick: notifier.pick,
              ),
              if (s.picked != null)
                ElevatedButton(onPressed: notifier.next, child: const Text('Next')),
            ],
          ),
        );
      },
    );
  }
}
