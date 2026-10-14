import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kit/choice_options.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/gap_question.dart';
import '../kit/question_builder.dart';
import '../kit/typed_answer_field.dart';
import 'quiz_notifier.dart';

/// The Quiz of one word group (learn-quiz): up to seven mixed questions
/// under exam rules (D-34, D-41, D-43) inside the shared frame (S-30): no
/// hint, no speaker, no right or wrong until the summary. The phase comes
/// from the notifier; this widget draws only the question body.
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key, this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = quizProvider(sessionId, groupId);
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
              if (q.choice case final choice?) ...[
                Text(q.kind == QuestionKind.wordToTranslation ? 'Pick the translation' : 'Pick the word'),
                const SizedBox(height: 16),
                Text(choice.prompt, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                ChoiceOptions(
                  key: ValueKey('choice-${s.attempt}-${s.index}'),
                  question: choice,
                  picked: s.answer?.picked,
                  reveal: false,
                  onPick: notifier.pick,
                ),
                if (!answered)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: notifier.skip, child: const Text('Skip')),
                  ),
              ],
              if (q.gap case final gap?) ...[
                const Text('Type the missing word'),
                const SizedBox(height: 16),
                GapPrompt(gap),
                const SizedBox(height: 16),
                TypedAnswerField(
                  key: ValueKey('gap-${s.attempt}-${s.index}-${gap.rowId}'),
                  expected: gap.answer,
                  mode: TypedAnswerMode.exam,
                  onSubmit: notifier.submit,
                ),
              ],
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
