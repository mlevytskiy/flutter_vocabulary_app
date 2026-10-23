import 'package:flutter/material.dart';

import '../../../core/services/learn_api_service.dart';
import '../kit/sentence_check.dart';
import '../kit/word_marks.dart';
import 'translate_sentences_notifier.dart';

/// One translation question (learn-translate-sentences, D-34): the Ukrainian
/// sentence with the cue in bold, the kit's exam field under it and, once the
/// word is final, the model translation with the word in bold. The old screen
/// and the session's page frame both draw it; [onDone] gets the word's final
/// result once.
class TranslateSentencesPageBody extends StatefulWidget {
  const TranslateSentencesPageBody({super.key, required this.card, required this.onDone, this.fieldKey});

  final TranslateCard card;
  final ValueChanged<SentenceResult> onDone;

  /// The field's key; the old screen keys it per round and word.
  final Key? fieldKey;

  @override
  State<TranslateSentencesPageBody> createState() => _TranslateSentencesPageBodyState();
}

class _TranslateSentencesPageBodyState extends State<TranslateSentencesPageBody> {
  /// The field's result for the shown card; null until the word is final.
  SentenceResult? _result;
  TranslateCard? _resultCard;

  void _done(SentenceResult result) {
    setState(() {
      _result = result;
      _resultCard = widget.card;
    });
    widget.onDone(result);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final style = Theme.of(context).textTheme;
    final done = _result != null && identical(_resultCard, card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Translate into English.'),
        const SizedBox(height: 8),
        Text.rich(
          key: const ValueKey('translate-source'),
          TextSpan(children: cueSpans(card.source, card.cue)),
          style: style.titleMedium,
        ),
        const SizedBox(height: 16),
        SentenceCheckField(
          key: widget.fieldKey,
          word: card.word,
          translation: card.translation,
          task: LearnCheckTask.translate,
          extra: card.source,
          mode: SentenceCheckMode.exam,
          onDone: _done,
        ),
        if (done) ...[
          const SizedBox(height: 16),
          const Text('Model translation:'),
          Text.rich(
            key: const ValueKey('translate-model'),
            TextSpan(children: boldWord(card.model, card.word)),
          ),
        ],
      ],
    );
  }
}
