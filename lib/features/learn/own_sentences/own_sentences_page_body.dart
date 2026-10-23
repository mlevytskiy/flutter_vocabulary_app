import 'package:flutter/material.dart';

import '../../../core/services/learn_api_service.dart';
import '../kit/sentence_check.dart';
import 'own_sentences_notifier.dart';

/// One own-sentences question (learn-own-sentences, D-34): the word, one
/// prompt and the kit's exam field. The old screen and the session's page
/// frame both draw it; [onDone] gets the word's final result once.
class OwnSentencesPageBody extends StatelessWidget {
  const OwnSentencesPageBody({super.key, required this.card, required this.onDone, this.fieldKey});

  final OwnCard card;
  final ValueChanged<SentenceResult> onDone;

  /// The field's key; the old screen keys it per round and word.
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(card.word, key: const ValueKey('own-word'), style: style.headlineMedium),
        const SizedBox(height: 8),
        Text('Write a sentence with “${card.word}”.'),
        const SizedBox(height: 16),
        SentenceCheckField(
          key: fieldKey,
          word: card.word,
          translation: card.translation,
          task: LearnCheckTask.own,
          mode: SentenceCheckMode.exam,
          onDone: onDone,
        ),
      ],
    );
  }
}
