import 'package:flutter/material.dart';

import '../kit/choice_options.dart';
import '../kit/gap_question.dart';
import '../kit/question_builder.dart';
import '../kit/typed_answer_field.dart';
import '../kit/typed_match.dart';
import '../session/exercise_page.dart';
import 'quiz_pages.dart';

/// One Quiz question under exam rules (learn-quiz D-34, D-41, D-43): a choice
/// question with Skip while it is open, or a gap question with the exam's
/// typed field. Drawn by the old screen and by a session page
/// (learn-redesign ADR-0003). [choiceKey] and [gapKey] key the option list
/// and the typed field.
class QuizPageBody extends StatelessWidget {
  const QuizPageBody({
    super.key,
    required this.question,
    required this.picked,
    required this.answered,
    required this.onPick,
    required this.onSkip,
    required this.onSubmit,
    this.onChanged,
    this.choiceKey,
    this.gapKey,
  });

  final QuizQuestion question;
  final int? picked;
  final bool answered;
  final ValueChanged<int> onPick;
  final VoidCallback onSkip;
  final ValueChanged<TypedAnswerResult> onSubmit;
  final ValueChanged<String>? onChanged;
  final Key? choiceKey;
  final Key? gapKey;

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (q.choice case final choice?) ...[
          Text(q.kind == QuestionKind.wordToTranslation ? 'Pick the translation' : 'Pick the word'),
          const SizedBox(height: 16),
          Text(choice.prompt, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          ChoiceOptions(
            key: choiceKey,
            question: choice,
            picked: picked,
            reveal: false,
            onPick: onPick,
          ),
          if (!answered)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onSkip, child: const Text('Skip')),
            ),
        ],
        if (q.gap case final gap?) ...[
          const Text('Type the missing word'),
          const SizedBox(height: 16),
          GapPrompt(gap),
          const SizedBox(height: 16),
          TypedAnswerField(
            key: gapKey,
            expected: gap.answer,
            mode: TypedAnswerMode.exam,
            onSubmit: onSubmit,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

/// [QuizPageBody] in a learning session. A choice page is done on its first
/// tap (or Skip, a miss); a gap page is ready for Check once something is
/// typed, the check matching it as the typed field does, and the field's own
/// Send or Skip makes it done. It never records a word result (AC-15).
class QuizSessionBody extends StatefulWidget {
  const QuizSessionBody({super.key, required this.question, required this.answer});

  final QuizQuestion question;
  final PageAnswer answer;

  @override
  State<QuizSessionBody> createState() => _QuizSessionBodyState();
}

class _QuizSessionBodyState extends State<QuizSessionBody> {
  int? _picked;
  bool _answered = false;

  String get _rowId => widget.question.rowId;

  void _done(bool right) {
    if (_answered) return;
    setState(() => _answered = true);
    widget.answer.done({_rowId: right});
  }

  void _pick(int option) {
    if (_answered) return;
    _picked = option;
    _done(option == widget.question.choice!.rightIndex);
  }

  void _changed(String text) {
    if (_answered) return;
    if (text.trim().isEmpty) {
      widget.answer.notReady();
    } else {
      final expected = widget.question.gap!.answer;
      widget.answer.ready(() async => {_rowId: matchTyped(text, expected).isRight});
    }
  }

  @override
  Widget build(BuildContext context) => QuizPageBody(
        question: widget.question,
        picked: _picked,
        answered: _answered,
        onPick: _pick,
        onSkip: () => _done(false),
        onSubmit: (result) => _done(result.match.isRight && !result.gaveUp),
        onChanged: _changed,
      );
}
