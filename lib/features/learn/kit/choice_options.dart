import 'package:flutter/material.dart';

import 'question_builder.dart';

/// The four options of a choice question (learn-pick-the-answer S-28, D-17,
/// D-43): full-width buttons whose text wraps, never cut. [onPick] fires once;
/// later taps are ignored. With [reveal] (practice) the right option turns
/// green and a wrong [picked] one red; without it (exams) only the picked
/// option is marked, in a neutral colour.
class ChoiceOptions extends StatefulWidget {
  const ChoiceOptions({
    super.key,
    required this.question,
    required this.picked,
    required this.reveal,
    required this.onPick,
  });

  final Question question;

  /// The index tapped so far, or null while the question is open.
  final int? picked;
  final bool reveal;
  final ValueChanged<int> onPick;

  @override
  State<ChoiceOptions> createState() => _ChoiceOptionsState();
}

class _ChoiceOptionsState extends State<ChoiceOptions> {
  bool _fired = false;

  @override
  void didUpdateWidget(ChoiceOptions old) {
    super.didUpdateWidget(old);
    if (old.question != widget.question) _fired = false;
  }

  Color? _color(int i) {
    final picked = widget.picked;
    if (picked == null) return null;
    if (!widget.reveal) return i == picked ? Colors.blueGrey : null;
    if (i == widget.question.rightIndex) return Colors.green;
    return i == picked ? Colors.red : null;
  }

  void _tap(int i) {
    if (_fired || widget.picked != null) return;
    _fired = true;
    widget.onPick(i);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              key: ValueKey('option-$i'),
              style: ElevatedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(16),
              ).copyWith(
                backgroundColor: _color(i) == null ? null : WidgetStatePropertyAll(_color(i)),
              ),
              onPressed: () => _tap(i),
              child: Text(widget.question.options[i], textAlign: TextAlign.left),
            ),
          ),
      ],
    );
  }
}
