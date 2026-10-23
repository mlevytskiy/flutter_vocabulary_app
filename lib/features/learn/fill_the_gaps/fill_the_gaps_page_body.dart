import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../kit/gap_question.dart';
import '../kit/typed_answer_field.dart';

/// One fill-the-gaps question (S-45, S-46), cut from the screen
/// (learn-redesign ADR-0003): the gap prompt, the verdict once [result] is
/// final and the typed answer field. [onAnswered] gets the field's final
/// answer. Used by the old screen and by the session's gap pages.
class FillTheGapsPageBody extends StatelessWidget {
  const FillTheGapsPageBody({super.key, required this.question, this.result, required this.onAnswered});

  final GapQuestion question;
  final TypedAnswerResult? result;
  final ValueChanged<TypedAnswerResult> onAnswered;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GapPrompt(question, revealed: result != null),
        const SizedBox(height: 16),
        if (result != null)
          Text(
            result.match.isRight ? 'Right' : 'Missed',
            key: const ValueKey('gap-verdict'),
            style: TextStyle(
              color: result.match.isRight
                  ? AppDecor.of(context).right
                  : AppDecor.of(context).wrong,
              fontWeight: FontWeight.bold,
            ),
          ),
        TypedAnswerField(
          key: ValueKey('gap-${question.rowId}'),
          expected: question.answer,
          mode: TypedAnswerMode.practice,
          onSubmit: onAnswered,
        ),
      ],
    );
  }
}
