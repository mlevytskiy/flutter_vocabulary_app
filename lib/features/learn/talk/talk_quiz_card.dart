import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../session/self_check.dart';
import '../session/self_check_card.dart';
import 'talk_quiz.dart';
import 'talk_widgets.dart' show talkRound;

/// The quick check card.
const talkQuizCardKey = ValueKey('talk-quiz');

/// The quick check inside the talk (owner, 2026-10-24), drawn as a chat
/// card: Learn's exercise kinds — Translate, Fill the gap, Pick the answer,
/// Match definitions — one step at a time. A spoken step is answered with
/// the talk's mic or field ([TalkQuizItem.spoken]); the others by tapping
/// here. A null [quiz] is still loading. A closed quiz shows its score only.
/// After the exercises, a word missed or used only after its hint gets a
/// self-check step (self-check-cards AC-11): the self-check card at chat-card
/// size, rated through [onRate].
class TalkQuizCard extends StatefulWidget {
  const TalkQuizCard({
    super.key,
    required this.quiz,
    required this.onPick,
    required this.onMatch,
    required this.onNext,
    this.onRate,
  });

  final TalkQuiz? quiz;
  final ValueChanged<String> onPick;
  final void Function(String rowId, String definitionRowId) onMatch;
  final VoidCallback onNext;
  final ValueChanged<SelfRating>? onRate;

  @override
  State<TalkQuizCard> createState() => _TalkQuizCardState();
}

class _TalkQuizCardState extends State<TalkQuizCard> {
  /// Match definitions: the word chip picked, waiting for its definition.
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final quiz = widget.quiz;
    final r = talkRound(decor, 16);

    Widget body;
    if (quiz == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary)),
          const SizedBox(width: 10),
          Text('Preparing a quick check…', style: theme.textTheme.bodyMedium),
        ]),
      );
    } else if (quiz.closed) {
      body = Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('${quiz.rightCount} of ${quiz.wordCount} words right',
            key: const ValueKey('talk-quiz-score'), style: theme.textTheme.bodyLarge),
      );
    } else {
      body = _step(context, quiz);
    }

    return Container(
      key: talkQuizCardKey,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.task_alt_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Quick check', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (quiz != null && !quiz.closed)
              Text('${quiz.index + 1} / ${quiz.items.length}',
                  style: theme.textTheme.labelLarge?.copyWith(color: decor.muted)),
          ]),
          body,
        ],
      ),
    );
  }

  Widget _step(BuildContext context, TalkQuiz quiz) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final item = quiz.current;
    if (item.kind == TalkQuizKind.selfCheck) return _selfCheck(context, item);
    final children = <Widget>[];
    final title = switch (item.kind) {
      TalkQuizKind.translate => 'Say the English word for',
      TalkQuizKind.fillGap => 'Say the missing word',
      TalkQuizKind.pickAnswer => 'Pick the missing word',
      TalkQuizKind.matchDefinitions => 'Match each word to its meaning',
      TalkQuizKind.selfCheck => '',
    };
    children.add(Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: decor.muted)),
    ));
    if (item.kind != TalkQuizKind.matchDefinitions) {
      children.add(Text(
        item.prompt,
        key: const ValueKey('talk-quiz-prompt'),
        style: (item.kind == TalkQuizKind.translate ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700, height: 1.35),
      ));
    }
    switch (item.kind) {
      case TalkQuizKind.translate || TalkQuizKind.fillGap:
        if (!item.done) {
          children.add(Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Speak, or type below', style: theme.textTheme.bodySmall?.copyWith(color: decor.muted)),
          ));
        }
      case TalkQuizKind.pickAnswer:
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in item.options)
              _OptionChip(
                text: o,
                state: !item.done
                    ? _Mark.none
                    : o == item.word.word
                        ? _Mark.right
                        : o == item.answer
                            ? _Mark.wrong
                            : _Mark.none,
                onTap: item.done ? null : () => widget.onPick(o),
              ),
          ]),
        ));
      case TalkQuizKind.selfCheck:
        break;
      case TalkQuizKind.matchDefinitions:
        children.add(Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in item.words)
            _OptionChip(
              text: w.word,
              state: item.matched.contains(w.rowId)
                  ? _Mark.right
                  : _picked == w.rowId
                      ? _Mark.picked
                      : _Mark.none,
              onTap: item.matched.contains(w.rowId) ? null : () => setState(() => _picked = w.rowId),
            ),
        ]));
        children.add(const SizedBox(height: 8));
        for (final w in item.words) {
          final matched = item.matched.contains(w.rowId);
          children.add(Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              key: ValueKey('talk-quiz-definition-${w.rowId}'),
              borderRadius: BorderRadius.circular(talkRound(decor, 10)),
              onTap: matched || _picked == null
                  ? null
                  : () {
                      widget.onMatch(_picked!, w.rowId);
                      setState(() => _picked = null);
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: matched ? decor.learnRight.withValues(alpha: 0.18) : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(talkRound(decor, 10)),
                ),
                child: Text.rich(TextSpan(children: [
                  if (matched) TextSpan(text: '${w.word}: ', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: item.definitions[w.rowId] ?? ''),
                ])),
              ),
            ),
          ));
        }
    }
    if (item.done) {
      final right = item.kind == TalkQuizKind.matchDefinitions ? item.wrongRows.isEmpty : item.correct == true;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Icon(right ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: right ? decor.learnRight : decor.learnWrong, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              right
                  ? 'Right!'
                  : item.kind == TalkQuizKind.matchDefinitions
                      ? 'Done — with ${item.wrongRows.length} wrong ${item.wrongRows.length == 1 ? 'try' : 'tries'}'
                      : 'It’s “${item.word.word}”',
              key: const ValueKey('talk-quiz-verdict'),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            key: const ValueKey('talk-quiz-next'),
            onPressed: widget.onNext,
            child: Text(quiz.isLast ? 'Back to the talk' : 'Next'),
          ),
        ]),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  /// A self-check step: flip the card, then rate how well the word is known.
  Widget _selfCheck(BuildContext context, TalkQuizItem item) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text('How well do you know it?', style: theme.textTheme.bodyMedium?.copyWith(color: decor.muted)),
      ),
      SelfCheckCard(
        key: ValueKey('talk-self-check-${item.word.rowId}'),
        row: item.word,
        box: item.box,
        side: item.side,
        now: DateTime.now(),
        afterMistake: item.afterMistake,
        onRated: (r) => widget.onRate?.call(r),
      ),
    ]);
  }
}

enum _Mark { none, picked, right, wrong }

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.text, required this.state, required this.onTap});

  final String text;
  final _Mark state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final (fill, ink, border) = switch (state) {
      _Mark.right => (decor.learnRight, decor.onLearnRight, decor.learnRight),
      _Mark.wrong => (decor.learnWrong, scheme.onError, decor.learnWrong),
      _Mark.picked => (scheme.primary, scheme.onPrimary, scheme.primary),
      _Mark.none => (Colors.transparent, scheme.onSurface, scheme.outlineVariant),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(talkRound(decor, 999)),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(talkRound(decor, 999)),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
