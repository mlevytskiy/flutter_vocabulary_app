import 'package:flutter/material.dart';

import '../../../core/theme/app_decor.dart';
import 'exercise_page.dart';

/// The frame around every learn page (learn-redesign, ADR-0011, option C1):
/// close, a three-segment step bar (Meet / Practise / Use) and "N / M" on top,
/// the exercise chip, a card holding [body], Check under it and, once
/// [verdict] is set, a verdict bar sliding up with Continue.
class LearnPageFrame extends StatefulWidget {
  const LearnPageFrame({
    super.key,
    required this.step,
    required this.stepProgress,
    required this.page,
    required this.total,
    required this.chip,
    required this.body,
    required this.answer,
    this.verdict,
    required this.onContinue,
    required this.onClose,
    required this.onResult,
  });

  final int step;
  final double stepProgress;
  final int page;
  final int total;
  final String chip;
  final Widget body;
  final PageAnswer answer;
  final PageVerdict? verdict;
  final VoidCallback onContinue;
  final VoidCallback onClose;
  final void Function(Map<String, bool>) onResult;

  @override
  State<LearnPageFrame> createState() => _LearnPageFrameState();
}

class _LearnPageFrameState extends State<LearnPageFrame> {
  bool _checking = false;
  Map<String, bool>? _reported;

  @override
  void initState() {
    super.initState();
    widget.answer.addListener(_onAnswer);
  }

  @override
  void didUpdateWidget(LearnPageFrame old) {
    super.didUpdateWidget(old);
    if (old.answer != widget.answer) {
      old.answer.removeListener(_onAnswer);
      widget.answer.addListener(_onAnswer);
      _reported = null;
    }
  }

  @override
  void dispose() {
    widget.answer.removeListener(_onAnswer);
    super.dispose();
  }

  void _onAnswer() {
    final results = widget.answer.results;
    if (results != null && !identical(results, _reported)) {
      _reported = results;
      // The body calls done() from its own callbacks; report after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onResult(results);
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final results = await widget.answer.runCheck();
      if (mounted) widget.onResult(results);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decor = AppDecor.of(context);
    final text = Theme.of(context).textTheme;
    final verdict = widget.verdict;
    final showCheck = !widget.answer.selfChecking && verdict == null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
              Expanded(child: _StepBar(widget.step, widget.stepProgress)),
              const SizedBox(width: 12),
              Text('${widget.page} / ${widget.total}',
                  style: text.labelLarge
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(decor.wordRowRadius),
                  ),
                  child: Text(widget.chip,
                      style: text.labelMedium
                          ?.copyWith(color: scheme.onSecondaryContainer)),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: decor.wordRowBorder,
                    borderRadius: BorderRadius.circular(
                        decor.wordRowRadius == 0 ? 0 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: widget.body,
                ),
                if (showCheck) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          widget.answer.isReady && !_checking ? _check : null,
                      child: const Text('Check'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => SizeTransition(
            sizeFactor: anim,
            axisAlignment: -1,
            child: child,
          ),
          child: verdict == null
              ? const SizedBox.shrink(key: ValueKey('no-verdict'))
              : _VerdictBar(
                  key: const ValueKey('verdict'),
                  verdict: verdict,
                  onContinue: widget.onContinue,
                ),
        ),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar(this.step, this.progress);

  final int step;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const names = ['Meet', 'Practise', 'Use'];
    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              label: names[i - 1],
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: ValueKey('step-$i'),
                  minHeight: 6,
                  value: i < step
                      ? 1
                      : i == step
                          ? progress.clamp(0.0, 1.0)
                          : 0,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VerdictBar extends StatelessWidget {
  const _VerdictBar(
      {super.key, required this.verdict, required this.onContinue});

  final PageVerdict verdict;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    final text = Theme.of(context).textTheme;
    final right = verdict.right;
    final fill = right ? decor.learnRight : decor.learnWrong;
    final on = right ? decor.onLearnRight : decor.onLearnWrong;
    return Container(
      width: double.infinity,
      color: fill,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(right ? '✓ Right' : '✗ Not quite',
                  style: text.titleMedium
                      ?.copyWith(color: on, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${verdict.word} — ${verdict.translation}',
                  style: text.bodyLarge?.copyWith(color: on)),
              if (!right && verdict.rightAnswer != null) ...[
                const SizedBox(height: 4),
                Text(verdict.rightAnswer!,
                    style: text.bodyMedium?.copyWith(color: on)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: on,
                    foregroundColor: fill,
                  ),
                  onPressed: onContinue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
