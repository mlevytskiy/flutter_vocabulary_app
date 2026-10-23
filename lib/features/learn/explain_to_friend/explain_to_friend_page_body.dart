import 'package:flutter/material.dart';

import '../../../core/services/learn_api_service.dart';
import '../kit/sentence_check.dart';
import 'explain_to_friend_notifier.dart';

/// One explain-to-friend question in the Type mode (learn-explain-to-friend,
/// D-34, D-40): the word, one prompt and the kit's exam field with a 90 s
/// limit. It never asks for the mode: the old screen asks once per open and
/// draws this for Type; a learning session always uses it (sad §5.1).
/// [onDone] gets the word's final result once.
class ExplainToFriendPageBody extends StatelessWidget {
  const ExplainToFriendPageBody.typed({super.key, required this.card, required this.onDone, this.fieldKey});

  final ExplainCard card;
  final ValueChanged<SentenceResult> onDone;

  /// The field's key; the old screen keys it per round and word.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(card.word, key: const ValueKey('explain-word'), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Explain “${card.word}” in English. Do not use the word or a translation.'),
          const SizedBox(height: 16),
          SentenceCheckField(
            key: fieldKey,
            word: card.word,
            translation: card.translation,
            task: LearnCheckTask.explain,
            mode: SentenceCheckMode.exam,
            timeLimitSeconds: 90,
            onDone: onDone,
          ),
        ],
      );
}
