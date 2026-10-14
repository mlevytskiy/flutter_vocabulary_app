import 'package:flutter/material.dart';

import 'typed_match.dart';

/// Practice (Step 1–2, D-19) or exam (Step 3, D-41).
enum TypedAnswerMode { practice, exam }

/// The final answer to a typed question.
class TypedAnswerResult {
  const TypedAnswerResult({required this.match, required this.answer, required this.firstTry, required this.gaveUp});

  /// [TypedMatch.almost] counts as right.
  final TypedMatch match;

  /// What the learner typed last; empty after "Show answer" or Skip.
  final String answer;

  /// Right (or almost) on the first try.
  final bool firstTry;

  /// Ended by "Show answer" (practice) or Skip (exam): missed / repeat.
  final bool gaveUp;
}

/// A typed answer (learn-kit AC-13, AC-14, S-11): the keyboard opens at once
/// with autocorrect and suggestions off, the Send key submits, and an empty
/// answer is not submitted. In practice a first wrong answer shows the first
/// letter and the letter count and allows one more try, after which the
/// answer shows; "Show answer" ends the word as missed. In an exam there is no
/// hint, no second try and no "Show answer", only Skip. [onSubmit] is called
/// once, with the final answer; the field then stays read-only.
class TypedAnswerField extends StatefulWidget {
  const TypedAnswerField({
    super.key,
    required this.expected,
    required this.mode,
    required this.onSubmit,
  });

  final String expected;
  final TypedAnswerMode mode;
  final ValueChanged<TypedAnswerResult> onSubmit;

  @override
  State<TypedAnswerField> createState() => _TypedAnswerFieldState();
}

class _TypedAnswerFieldState extends State<TypedAnswerField> {
  final _controller = TextEditingController();
  int _tries = 0;
  TypedAnswerResult? _final;

  bool get _practice => widget.mode == TypedAnswerMode.practice;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(TypedAnswerResult result) {
    setState(() => _final = result);
    widget.onSubmit(result);
  }

  void _submit() {
    final answer = _controller.text;
    if (_final != null || answer.trim().isEmpty) return;
    _tries++;
    final match = matchTyped(answer, widget.expected);
    if (match.isRight || !_practice || _tries >= 2) {
      _finish(TypedAnswerResult(match: match, answer: answer, firstTry: _tries == 1 && match.isRight, gaveUp: false));
    } else {
      setState(() {});
    }
  }

  void _giveUp() {
    if (_final != null) return;
    _finish(const TypedAnswerResult(match: TypedMatch.wrong, answer: '', firstTry: false, gaveUp: true));
  }

  String get _hint {
    final letters = widget.expected.trim();
    final count = letters.replaceAll(' ', '').length;
    return 'Starts with “${letters.isEmpty ? '' : letters[0]}”, $count letters';
  }

  /// What shows under the field once the answer is final (practice only:
  /// an exam shows nothing until the summary, D-34).
  String? get _finalLine {
    final result = _final;
    if (result == null || !_practice) return null;
    if (result.match == TypedMatch.almost) return 'Almost: ${widget.expected}';
    if (!result.match.isRight) return 'Answer: ${widget.expected}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final done = _final != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          readOnly: done,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
        ),
        if (_practice && _tries == 1 && !done) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_hint)),
        if (_finalLine != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_finalLine!)),
        if (!done)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _giveUp,
              child: Text(_practice ? 'Show answer' : 'Skip'),
            ),
          ),
      ],
    );
  }
}
