import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/learn_api_service.dart';
import '../kit/exam_countdown.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_scaffold.dart';
import '../kit/sentence_check.dart';
import 'explain_to_friend_notifier.dart';

/// The explain-to-friend exam of one word group (learn-explain-to-friend)
/// inside the shared frame (S-30): the mode question once per open, then per
/// word only the word and one prompt — the kit's exam field with a 90 s limit
/// (Type), or a 30 s countdown and the friend's answer (With a friend). Nothing
/// else is shown on the card (D-34, D-40). The phase comes from the notifier.
class ExplainToFriendScreen extends ConsumerWidget {
  const ExplainToFriendScreen({super.key, this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = explainToFriendProvider(collectionId, groupId);
    final async = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final phase = async.when(
      data: (s) => s.phase,
      loading: () => const ExerciseLoading(),
      error: (e, _) => ExerciseFailed(failureOf(e)),
    );
    return ExerciseScaffold(
      title: 'Explain it to a friend',
      phase: phase,
      onRetry: notifier.retry,
      onNextRound: notifier.nextRound,
      roundBuilder: (context, round) {
        final s = async.requireValue;
        final card = s.card;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: card == null
              ? _modeQuestion(notifier)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Word ${s.index + 1} of ${s.cards.length}'),
                    const SizedBox(height: 16),
                    Text(card.word, key: const ValueKey('explain-word'), style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    ...s.mode == ExplainMode.type ? _typeCard(s, card, notifier) : _friendCard(s, card, notifier),
                  ],
                ),
        );
      },
    );
  }

  Widget _modeQuestion(ExplainToFriend notifier) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('How will you explain the words?'),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => notifier.chooseMode(ExplainMode.type), child: const Text('Type')),
          const SizedBox(height: 4),
          const Text('Type it in English in 90 seconds. The AI checks it.'),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => notifier.chooseMode(ExplainMode.friend), child: const Text('With a friend')),
          const SizedBox(height: 4),
          const Text('Say it aloud in 30 seconds. The person next to you decides. Results are not saved.'),
        ],
      );

  List<Widget> _typeCard(ExplainState s, ExplainCard card, ExplainToFriend notifier) {
    final typed = s.result?.typed;
    final line = switch (typed) {
      SentenceResult(outcome: SentenceOutcome.skipped, timedOut: true) => 'Time is up',
      SentenceResult(outcome: SentenceOutcome.skipped) => 'Skipped',
      SentenceResult(outcome: SentenceOutcome.notChecked) => 'Not checked',
      _ => null,
    };
    return [
      Text('Explain “${card.word}” in English. Do not use the word or a translation.'),
      const SizedBox(height: 16),
      SentenceCheckField(
        key: ValueKey('check-${s.round}-${card.rowId}'),
        word: card.word,
        translation: card.translation,
        task: LearnCheckTask.explain,
        mode: SentenceCheckMode.exam,
        timeLimitSeconds: 90,
        onDone: notifier.done,
      ),
      if (typed != null) ...[
        if (line != null) ...[const SizedBox(height: 8), Text(line)],
        const SizedBox(height: 16),
        ElevatedButton(onPressed: notifier.next, child: const Text('Next')),
      ],
    ];
  }

  List<Widget> _friendCard(ExplainState s, ExplainCard card, ExplainToFriend notifier) {
    final answer = s.result?.friend;
    return [
      Text('Explain “${card.word}” aloud to the person next to you. Do not say the word or a translation.'),
      const SizedBox(height: 16),
      if (answer == null && !s.asking) ...[
        ExamCountdown(key: ValueKey('friend-${s.round}-${card.rowId}'), seconds: 30, onZero: notifier.friendReady),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: notifier.friendReady, child: const Text('Done')),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => notifier.friendAnswer(FriendAnswer.skipped), child: const Text('Skip')),
        ),
      ],
      if (answer == null && s.asking) ...[
        const Text('Did they understand?'),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: () => notifier.friendAnswer(FriendAnswer.understood), child: const Text('Understood')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => notifier.friendAnswer(FriendAnswer.notYet), child: const Text('Not yet')),
      ],
      if (answer != null) ...[
        Text(explainDetail(ExplainResult.friend(answer))),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: notifier.next, child: const Text('Next')),
      ],
    ];
  }
}
