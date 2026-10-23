import 'package:flutter/material.dart';

import '../kit/choice_options.dart';
import '../kit/question_builder.dart';
import '../session/exercise_page.dart';

/// One pick-the-answer question (learn-pick-the-answer S-28): the task line,
/// the prompt and four options that reveal right and wrong. Drawn by the old
/// screen and by a session page (learn-redesign ADR-0003).
class PickTheAnswerPageBody extends StatelessWidget {
  const PickTheAnswerPageBody({
    super.key,
    required this.question,
    required this.kind,
    required this.picked,
    required this.onPick,
  });

  final Question question;
  final QuestionKind kind;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(kind == QuestionKind.wordToTranslation ? 'Pick the translation' : 'Pick the word'),
        const SizedBox(height: 16),
        Text(question.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        ChoiceOptions(
          question: question,
          picked: picked,
          reveal: true,
          onPick: onPick,
        ),
      ],
    );
  }
}

/// [PickTheAnswerPageBody] in a learning session: the first tap is final
/// (D-17) and goes to [answer] as done, right when it is the right option.
class PickTheAnswerSessionBody extends StatefulWidget {
  const PickTheAnswerSessionBody({super.key, required this.question, required this.kind, required this.answer});

  final Question question;
  final QuestionKind kind;
  final PageAnswer answer;

  @override
  State<PickTheAnswerSessionBody> createState() => _PickTheAnswerSessionBodyState();
}

class _PickTheAnswerSessionBodyState extends State<PickTheAnswerSessionBody> {
  int? _picked;

  void _pick(int option) {
    if (_picked != null) return;
    setState(() => _picked = option);
    widget.answer.done({widget.question.rowId: option == widget.question.rightIndex});
  }

  @override
  Widget build(BuildContext context) => PickTheAnswerPageBody(
        question: widget.question,
        kind: widget.kind,
        picked: _picked,
        onPick: _pick,
      );
}
