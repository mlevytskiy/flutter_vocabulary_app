import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/word_box.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../../core/theme/app_decor.dart';
import '../../words/widgets/pronunciation_buttons.dart';
import 'self_check.dart';

/// The self-check card (learn-welcome AC-07, AC-18; ADR-0006). The front shows
/// one side of [row] -- its Ukrainian translation for [side] `'uk'` (recall
/// the English word) or its English word for `'en'` (recall the meaning) --
/// and "Tap to flip". A tap turns it over to the word, its sound, the
/// translation and the [wordContext] line. The four rating buttons stay
/// disabled until the flip; under each is the box it leads to ([boxLabel]).
///
/// It keeps nothing: a tap on a rating only calls [onRated] (once), and the
/// caller saves the move ([rateBox]).
class SelfCheckCard extends StatefulWidget {
  const SelfCheckCard({
    super.key,
    required this.row,
    required this.box,
    required this.side,
    required this.now,
    this.afterMistake = false,
    this.wordContext = '',
    this.contextByAi = false,
    this.onSpeak,
    required this.onRated,
  });

  /// The word being checked and its Leitner box (null: a new word).
  final WordPair row;
  final WordBox? box;

  /// The side shown first: `'uk'` or `'en'` (see [nextSide]).
  final String side;

  /// The day the captions count from.
  final DateTime now;

  /// Easy right after a mistake counts as Medium (AC-08).
  final bool afterMistake;

  /// The word's context sentence, shown in italic on the back with "from the
  /// source" or, when [contextByAi], "written by AI"; nothing when empty.
  final String wordContext;
  final bool contextByAi;

  /// Plays the word; null speaks it through the app's pronunciation service.
  final ValueChanged<Accent>? onSpeak;

  final ValueChanged<SelfRating> onRated;

  @override
  State<SelfCheckCard> createState() => _SelfCheckCardState();
}

class _SelfCheckCardState extends State<SelfCheckCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  bool _flipped = false;
  bool _rated = false;

  @override
  void didUpdateWidget(SelfCheckCard old) {
    super.didUpdateWidget(old);
    if (old.row.rowId != widget.row.rowId || old.side != widget.side) {
      _flipped = false;
      _rated = false;
      _turn.value = 0;
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipped) return;
    setState(() => _flipped = true);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _turn.value = 1;
    } else {
      _turn.forward();
    }
  }

  void _rate(SelfRating rating) {
    if (!_flipped || _rated) return;
    _rated = true;
    widget.onRated(rating);
  }

  Future<void> _speak(Accent accent) async {
    final onSpeak = widget.onSpeak;
    if (onSpeak != null) {
      onSpeak(accent);
      return;
    }
    final pronunciation = ProviderScope.containerOf(context, listen: false)
        .read(pronunciationServiceProvider);
    try {
      await pronunciation.speak(widget.row.word, accent: accent);
    } on PronunciationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const ValueKey('self-check-card'),
          behavior: HitTestBehavior.opaque,
          onTap: _flip,
          child: AnimatedBuilder(
            animation: _turn,
            builder: (context, _) {
              final t = _turn.value;
              final back = t >= 0.5;
              // The back is turned a half turn further, so it reads the
              // right way round once the card has turned over.
              final angle = math.pi * t + (back ? math.pi : 0);
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: back ? _back(context) : _front(context),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _ratings(context),
      ],
    );
  }

  Widget _front(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final decor = AppDecor.of(context);
    final shown =
        widget.side == 'en' ? widget.row.word : widget.row.translation;
    return Padding(
      key: const ValueKey('self-check-front'),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(shown, textAlign: TextAlign.center, style: style.headlineSmall),
          const SizedBox(height: 16),
          Text('Tap to flip',
              style: style.bodySmall?.copyWith(color: decor.muted)),
        ],
      ),
    );
  }

  Widget _back(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final decor = AppDecor.of(context);
    final contextText = widget.wordContext.trim();
    return Padding(
      key: const ValueKey('self-check-back'),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                  child: Text(widget.row.word, style: style.headlineSmall)),
              const SizedBox(width: 8),
              PronunciationButtons(onSpeak: _speak),
            ],
          ),
          if (widget.row.translation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(widget.row.translation, style: style.titleMedium),
          ],
          if (contextText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              contextText,
              key: const ValueKey('self-check-context'),
              style: style.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 4),
            if (widget.contextByAi)
              Row(
                key: const ValueKey('self-check-context-ai'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: decor.aiAccent),
                  const SizedBox(width: 6),
                  Text('written by AI',
                      style: style.bodySmall?.copyWith(color: decor.aiAccent)),
                ],
              )
            else
              Text('from the source',
                  key: const ValueKey('self-check-context-source'),
                  style: style.bodySmall?.copyWith(color: decor.muted)),
          ],
        ],
      ),
    );
  }

  Widget _ratings(BuildContext context) {
    final decor = AppDecor.of(context);
    final buttons = [
      (SelfRating.dontRemember, "I don't remember", decor.rateForgot),
      (SelfRating.hard, 'Hard', decor.rateHard),
      (SelfRating.medium, 'Medium', decor.rateMedium),
      (SelfRating.easy, 'Easy', decor.rateEasy),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (rating, label, color)) in buttons.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _RatingButton(
              key: ValueKey('rate-${rating.name}'),
              label: label,
              caption: boxLabel(widget.box, rating, widget.now,
                  afterMistake: widget.afterMistake),
              color: color,
              outline: decor.picOutline,
              onPressed: _flipped ? () => _rate(rating) : null,
            ),
          ),
        ],
      ],
    );
  }
}

/// One rating button with its box caption under it.
class _RatingButton extends StatelessWidget {
  const _RatingButton({
    super.key,
    required this.label,
    required this.caption,
    required this.color,
    required this.outline,
    required this.onPressed,
  });

  final String label;
  final String caption;
  final Color color;
  final bool outline;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final on = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
          AppDecor.of(context).wordRowRadius.clamp(0, 12).toDouble()),
    );
    const padding = EdgeInsets.symmetric(horizontal: 4, vertical: 10);
    final text =
        Text(label, textAlign: TextAlign.center, maxLines: 2, softWrap: true);
    final button = outline
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              disabledForegroundColor: color.withValues(alpha: 0.38),
              side: BorderSide(
                  color: onPressed == null
                      ? color.withValues(alpha: 0.38)
                      : color),
              shape: shape,
              padding: padding,
            ),
            child: text,
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: on,
              disabledBackgroundColor: color.withValues(alpha: 0.3),
              disabledForegroundColor: on.withValues(alpha: 0.6),
              shape: shape,
              padding: padding,
            ),
            child: text,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        const SizedBox(height: 4),
        Text(caption,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppDecor.of(context).muted)),
      ],
    );
  }
}
