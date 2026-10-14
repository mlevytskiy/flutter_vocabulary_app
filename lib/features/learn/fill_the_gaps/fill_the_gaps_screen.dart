import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/gap_question.dart';
import '../kit/typed_answer_field.dart';
import 'fill_the_gaps_notifier.dart';

class FillTheGapsScreen extends ConsumerWidget {
  const FillTheGapsScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = fillTheGapsProvider(sessionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Fill the gaps',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final question = s.question!;
        final result = s.result;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Question ${s.index + 1} of ${s.questions.length}'),
              const SizedBox(height: 8),
              const Text('Type the missing word'),
              const SizedBox(height: 16),
              GapPrompt(question, revealed: result != null),
              const SizedBox(height: 16),
              if (result != null)
                Text(
                  result.match.isRight ? 'Right' : 'Missed',
                  key: const ValueKey('gap-verdict'),
                  style: TextStyle(
                    color: result.match.isRight ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              TypedAnswerField(
                key: ValueKey('gap-${question.rowId}'),
                expected: question.answer,
                mode: TypedAnswerMode.practice,
                onSubmit: notifier.answer,
              ),
              if (result != null) ...[
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
