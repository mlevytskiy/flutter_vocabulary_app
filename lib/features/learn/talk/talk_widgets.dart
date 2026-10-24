import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/theme/app_theme.dart';
import 'talk_text.dart';

/// The pieces of the Direction B talk screen (talk-screen-b, owner
/// 2026-10-24; design board https://claude.ai/artifact/V9mkcFBdK1DNeNDsRq4KrF):
/// the tutor header, the chat bubbles with their tappable practice words and
/// karaoke, the dashed live bubble, the pause ring, the small waveform and
/// the word strip's chips. Every colour comes from the theme and [AppDecor].

/// The word strip: one horizontal line of all the talk's words.
const talkStripKey = ValueKey('talk-strip');

/// The chat log's list.
const talkLogKey = ValueKey('talk-log');

/// The bubble of message [index].
ValueKey<String> talkBubbleKey(int index) => ValueKey('talk-bubble-$index');

/// [r] as the theme rounds its rows: Windows 95's square rows give square
/// bubbles, Amber Terminal's 2 px rows nearly square ones.
double talkRound(AppDecor decor, double r) => math.min(r, decor.wordRowRadius * 2);

/// Who the learner talks to: a gradient monogram and "Emma — Your English
/// partner · <collection>", with End talk on the right.
class TalkTutorHeader extends StatelessWidget {
  const TalkTutorHeader({super.key, required this.collectionName, required this.onEnd});

  final String collectionName;

  /// End talk; null while there is nothing to end.
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final subtitle = collectionName.trim().isEmpty
        ? 'Your English partner'
        : 'Your English partner · ${collectionName.trim()}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(talkRound(decor, 19)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(scheme.primary, scheme.surface, 0.45)!, scheme.primary],
              ),
            ),
            child: Text(
              'E',
              style: (theme.textTheme.titleLarge ?? const TextStyle())
                  .copyWith(color: scheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w700, height: 1),
              textScaler: TextScaler.noScaling,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Emma',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: decor.muted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEnd, child: const Text('End talk')),
        ],
      ),
    );
  }
}

/// One message: the AI's on the left on a soft surface with a small
/// bottom-left corner, the learner's on the right in the accent colour. The
/// talk's [words] are highlighted — accent, bold, dotted underline; used ones
/// in the "used" colour — and a tap on one calls [onWord] with where it was
/// tapped. With [spokenEnd] the AI's line is being read: the part after it is
/// faded until the voice reaches it (karaoke).
class TalkBubble extends StatefulWidget {
  const TalkBubble({
    super.key,
    required this.index,
    required this.text,
    required this.mine,
    required this.maxWidth,
    this.words = const [],
    this.usedRows = const {},
    this.spokenEnd,
    this.onWord,
  });

  final int index;
  final String text;
  final bool mine;
  final double maxWidth;
  final List<WordPair> words;
  final Set<String> usedRows;
  final int? spokenEnd;
  final void Function(WordPair word, Offset globalPosition)? onWord;

  @override
  State<TalkBubble> createState() => _TalkBubbleState();
}

class _TalkBubbleState extends State<TalkBubble> {
  /// One recognizer per practice word, made on first use, freed with the
  /// bubble.
  final _taps = <String, TapGestureRecognizer>{};

  TapGestureRecognizer _tapFor(WordPair w) => _taps.putIfAbsent(
        w.rowId,
        () => TapGestureRecognizer()
          ..onTapUp = (d) {
            final word = widget.words.where((x) => x.rowId == w.rowId).firstOrNull;
            if (word != null) widget.onWord?.call(word, d.globalPosition);
          },
      );

  @override
  void dispose() {
    for (final t in _taps.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final mine = widget.mine;
    final ink = mine ? scheme.onPrimary : scheme.onSurface;
    final base = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(color: ink, fontSize: 15.5, height: 1.45);
    final speaking = widget.spokenEnd != null;
    Color fade(Color c) => c.withValues(alpha: c.a * 0.4);

    TextStyle styleOf(TalkSpan s) {
      var style = base;
      final w = s.word;
      if (w != null) {
        final used = widget.usedRows.contains(w.rowId);
        final colour = mine ? scheme.onPrimary : (used ? decor.learnRight : scheme.primary);
        style = style.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationStyle: mine ? TextDecorationStyle.solid : TextDecorationStyle.dotted,
          decorationColor: mine ? decor.learnRight : colour,
          decorationThickness: mine ? 2 : 1.6,
        );
      }
      return s.spoken ? style : style.copyWith(color: fade(style.color ?? ink));
    }

    final r = talkRound(decor, 18);
    final small = talkRound(decor, 6);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: talkBubbleKey(widget.index),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest,
          border: speaking ? Border.all(color: scheme.primary.withValues(alpha: 0.55), width: 1.5) : null,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
            bottomLeft: Radius.circular(mine ? r : small),
            bottomRight: Radius.circular(mine ? small : r),
          ),
        ),
        child: Text.rich(
          TextSpan(children: [
            for (final s in talkSpans(widget.text, widget.words, spokenEnd: widget.spokenEnd))
              TextSpan(
                text: s.text,
                style: styleOf(s),
                recognizer: s.word != null && widget.onWord != null ? _tapFor(s.word!) : null,
              ),
          ]),
          style: base,
        ),
      ),
    );
  }
}

/// The words being heard, in a dashed accent outline on the learner's side.
class TalkLiveBubble extends StatelessWidget {
  const TalkLiveBubble({super.key, required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final r = talkRound(decor, 18);
    final shape = BorderRadius.only(
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
      bottomLeft: Radius.circular(r),
      bottomRight: Radius.circular(talkRound(decor, 6)),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: CustomPaint(
          painter: _DashedBubble(color: scheme.primary, shape: shape),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              text,
              style: (theme.textTheme.bodyLarge ?? const TextStyle())
                  .copyWith(color: scheme.onSurface, fontSize: 15.5, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1.5 px dashed outline of [shape] (the dashes of `DashedAddButton`).
class _DashedBubble extends CustomPainter {
  const _DashedBubble({required this.color, required this.shape});

  final Color color;
  final BorderRadius shape;

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()..addRRect(shape.toRRect((Offset.zero & size).deflate(0.75)));
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBubble old) => old.color != color || old.shape != shape;
}

/// The ring around the mic: its track while listening, filling as the
/// learner's pause runs down to sending ([progress] 0–1).
class TalkRing extends StatelessWidget {
  const TalkRing({super.key, required this.progress, required this.active, required this.child});

  final double progress;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 68,
      height: 68,
      child: CustomPaint(
        painter: _RingPainter(
          track: active ? scheme.outlineVariant : Colors.transparent,
          fill: scheme.tertiary,
          progress: active ? progress : 0,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.track, required this.fill, required this.progress});

  final Color track;
  final Color fill;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (progress <= 0) return;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress.clamp(0, 1), false,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track || old.fill != fill;
}

/// Six small bars beside the mic while it listens; they move with each new
/// piece of what is heard ([seed]), so they follow the voice without a
/// running animation.
class TalkWave extends StatelessWidget {
  const TalkWave({super.key, required this.active, required this.seed});

  final bool active;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final colour = Theme.of(context).colorScheme.primary;
    final random = math.Random(seed);
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: 22,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 6; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 3,
                height: 22 * (seed == 0 ? 0.3 : 0.3 + 0.7 * random.nextDouble()),
                decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    );
  }
}

/// One word of the strip: ticked in the "used" colour, the word the AI steers
/// to outlined in the accent, the rest quiet. A tap calls [onTap] with the
/// chip's place on screen.
class TalkStripChip extends StatelessWidget {
  const TalkStripChip({super.key, required this.word, required this.used, required this.target, required this.onTap});

  final String word;
  final bool used;
  final bool target;
  final void Function(Rect globalRect) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final colour = used ? decor.onLearnRight : (target ? scheme.primary : decor.muted);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        onTap(box.localToGlobal(Offset.zero) & box.size);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: used ? decor.learnRight : null,
          borderRadius: BorderRadius.circular(talkRound(decor, 999)),
          border: used
              ? null
              : Border.all(color: target ? scheme.primary : scheme.outlineVariant, width: 1.5),
        ),
        child: Text(
          used ? '$word ✓' : word,
          style: theme.textTheme.labelLarge?.copyWith(color: colour, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
