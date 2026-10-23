import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import 'quiz_notifier.dart';
import 'quiz_page_body.dart';

/// The Quiz of one word group (learn-quiz): up to seven mixed questions
/// under exam rules (D-34, D-41, D-43) inside the shared frame (S-30): no
/// hint, no speaker, no right or wrong until the summary. The phase comes
/// from the notifier; this widget draws only the question body.
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = quizProvider(collectionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Quiz',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: () {},
      onAgain: notifier.repeat,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final q = s.question!;
        final answered = s.answer != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Question ${s.index + 1} of ${s.questions.length}'),
              if (s.gapsUnavailable) const Text('Gap questions are unavailable'),
              const SizedBox(height: 8),
              QuizPageBody(
                question: q,
                picked: s.answer?.picked,
                answered: answered,
                onPick: notifier.pick,
                onSkip: notifier.skip,
                onSubmit: notifier.submit,
                choiceKey: ValueKey('choice-${s.attempt}-${s.index}'),
                gapKey: q.gap == null ? null : ValueKey('gap-${s.attempt}-${s.index}-${q.gap!.rowId}'),
              ),
              if (answered) ...[
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
