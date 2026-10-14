import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/word_result.dart';
import '../../../core/providers.dart';
import '../../../core/services/learn_api_service.dart';
import 'check_result_line.dart';
import 'check_verdict.dart';
import 'exercise_phase.dart';

/// Practice (Step 2) or exam (Step 3) sentence check (S-47).
enum SentenceCheckMode { practice, exam }

/// How a sentence word ended (S-48): [right] = `CheckRight`, [fixed] =
/// `CheckFixed`, [skipped] = Skip with no sent check, [notChecked] = Skip after
/// a sent check failed and was never answered.
enum SentenceOutcome { right, fixed, skipped, notChecked }

/// The final result of one word's sentence (S-48): [sentence] is the text sent
/// ("" when skipped before sending), [verdict] is null unless checked.
class SentenceResult {
  const SentenceResult({required this.outcome, required this.sentence, this.verdict});

  /// A checked sentence: right or fixed by [verdict].
  factory SentenceResult.checked(String sentence, CheckVerdict verdict) => SentenceResult(
        outcome: verdict is CheckRight ? SentenceOutcome.right : SentenceOutcome.fixed,
        sentence: sentence,
        verdict: verdict,
      );

  final SentenceOutcome outcome;
  final String sentence;
  final CheckVerdict? verdict;
}

/// Practice labels (S-48): a failed check never retried counts as skipped.
String practiceLabel(SentenceOutcome outcome) => switch (outcome) {
      SentenceOutcome.right => 'Right',
      SentenceOutcome.fixed => 'Fixed',
      SentenceOutcome.skipped || SentenceOutcome.notChecked => 'Skipped',
    };

/// An exam's word result (S-48, D-32: an error is no result).
WordResultLabel? examLabel(SentenceOutcome outcome) => switch (outcome) {
      SentenceOutcome.right => WordResultLabel.known,
      SentenceOutcome.fixed || SentenceOutcome.skipped => WordResultLabel.repeat,
      SentenceOutcome.notChecked => null,
    };

/// An exam summary's text for the outcome (S-48).
String examSummaryText(SentenceOutcome outcome) => switch (outcome) {
      SentenceOutcome.right => 'Known',
      SentenceOutcome.fixed || SentenceOutcome.skipped => 'Repeat',
      SentenceOutcome.notChecked => 'Not checked',
    };

/// The shared sentence field (S-47): type, pre-check (`sentenceProblem`), send
/// one check, judge it with `judgeCheck` and show the result line. One checked
/// sentence per word; Skip until the word is final. After a failed check,
/// practice unlocks the text and Retry sends the current text, an exam keeps
/// the sent text locked and Retry resends exactly it. [onDone] is called once.
/// The caller keys it per word and draws its own card and prompt above it.
class SentenceCheckField extends ConsumerStatefulWidget {
  const SentenceCheckField({
    super.key,
    required this.word,
    required this.translation,
    required this.task,
    this.extra = '',
    required this.mode,
    required this.onDone,
  });

  final String word;
  final String translation;
  final LearnCheckTask task;
  final String extra;
  final SentenceCheckMode mode;
  final ValueChanged<SentenceResult> onDone;

  @override
  ConsumerState<SentenceCheckField> createState() => _SentenceCheckFieldState();
}

class _SentenceCheckFieldState extends ConsumerState<SentenceCheckField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _checking = false;
  String? _problem;
  ExerciseFailure? _failure;

  /// The text of the last sent check that failed; an exam resends exactly it.
  String? _sent;
  SentenceResult? _final;

  bool get _exam => widget.mode == SentenceCheckMode.exam;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _finish(SentenceResult result) {
    _focus.unfocus();
    setState(() {
      _final = result;
      _checking = false;
    });
    widget.onDone(result);
  }

  Future<void> _send() async {
    if (_final != null || _checking) return;
    final String sentence;
    if (_exam && _sent != null) {
      sentence = _sent!;
    } else {
      final problem = sentenceProblem(_controller.text, widget.task);
      if (problem != null) {
        setState(() => _problem = problem);
        return;
      }
      sentence = _controller.text.trim();
    }
    setState(() {
      _problem = null;
      _checking = true;
      _sent = sentence;
    });
    final api = ref.read(learnApiServiceProvider);
    try {
      final reply = await api.check((
        word: widget.word,
        translation: widget.translation,
        sentence: sentence,
        task: widget.task,
        extra: widget.extra,
      ));
      if (!mounted) return;
      final verdict = judgeCheck(reply, sentence: sentence, word: widget.word, task: widget.task);
      _failure = null;
      _finish(SentenceResult.checked(sentence, verdict));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _failure = failureOf(e);
      });
    }
  }

  void _skip() {
    if (_final != null || _checking) return;
    final failed = _failure != null;
    _finish(SentenceResult(
      outcome: failed ? SentenceOutcome.notChecked : SentenceOutcome.skipped,
      sentence: failed ? _sent! : '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final result = _final;
    final locked = result != null || _checking || (_exam && _sent != null);
    final failure = _failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          readOnly: locked,
          keyboardType: TextInputType.text,
          minLines: 1,
          maxLines: null,
          inputFormatters: [FilteringTextInputFormatter.deny('\n')],
          textInputAction: TextInputAction.send,
          // Keeps the keyboard open after a refused Send (AC-06).
          onEditingComplete: () {},
          onSubmitted: (_) => _send(),
        ),
        if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!)),
        if (_checking)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Checking…'),
              ],
            ),
          ),
        if (result?.verdict != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CheckResultLine.verdict(result!.verdict!, word: widget.word),
          ),
        if (result == null && !_checking && failure != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CheckResultLine.failed(failure, onRetry: _send),
          ),
        if (result == null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _skip, child: const Text('Skip')),
          ),
      ],
    );
  }
}
