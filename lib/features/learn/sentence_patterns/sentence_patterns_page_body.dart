import 'package:flutter/material.dart';

import '../../../core/services/learn_api_service.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../words/widgets/pronunciation_buttons.dart';
import '../kit/sentence_check.dart';
import '../kit/word_marks.dart';
import 'sentence_patterns_notifier.dart';

/// One sentence-patterns card (S-15, S-50), cut from the screen
/// (learn-redesign ADR-0003): the sentence with the word in bold and its
/// listen buttons, the pattern, its use and the translation, then "My turn"
/// or, once [writing], the sentence check field. [onDone] gets the field's
/// final result. Used by the old screen and by the session's pattern pages.
class SentencePatternsPageBody extends StatelessWidget {
  const SentencePatternsPageBody({
    super.key,
    required this.card,
    required this.writing,
    this.result,
    required this.onStartWriting,
    required this.onDone,
    required this.onSpeak,
  });

  final PatternCard card;
  final bool writing;
  final SentenceResult? result;
  final VoidCallback onStartWriting;
  final ValueChanged<SentenceResult> onDone;
  final ValueChanged<Accent> onSpeak;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                key: const ValueKey('pattern-sentence'),
                TextSpan(children: boldWord(card.sentence, card.word)),
                style: style.titleMedium,
              ),
            ),
            PronunciationButtons(onSpeak: onSpeak),
          ],
        ),
        const SizedBox(height: 8),
        Text('Pattern: ${card.pattern}'),
        const SizedBox(height: 4),
        Text('Use it to: ${card.usage}'),
        const SizedBox(height: 8),
        Text(card.translation, style: style.bodySmall),
        const SizedBox(height: 16),
        if (!writing)
          ElevatedButton(onPressed: onStartWriting, child: const Text('My turn'))
        else ...[
          Text('Write your own sentence with “${card.word}” and this pattern.'),
          const SizedBox(height: 8),
          SentenceCheckField(
            key: ValueKey('check-${card.rowId}'),
            word: card.word,
            translation: card.translation,
            task: LearnCheckTask.pattern,
            extra: card.pattern,
            mode: SentenceCheckMode.practice,
            onDone: onDone,
          ),
          if (result != null && result.verdict == null) ...[
            const SizedBox(height: 8),
            Text(practiceLabel(result.outcome), key: const ValueKey('pattern-skipped')),
          ],
        ],
      ],
    );
  }
}
