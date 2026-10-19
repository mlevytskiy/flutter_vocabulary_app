import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_decor.dart';

/// The main screen's title: the collection's name on one line (collection-
/// naming, owner 2026-10-18). The old name stays while the Worker is asked;
/// when the AI's name replaces "Vocabulary N" on screen ([animate] true for
/// that change), the old letters swirl up and away left to right while the
/// new ones swirl up into place one after another (swirl float, owner
/// 2026-10-19), each settling from the top bar's
/// button colour to the title colour, while the title's width eases to the
/// new one. Any other change, and every change with animations turned off,
/// is shown at once.
class CollectionTitle extends StatefulWidget {
  const CollectionTitle({
    super.key,
    required this.text,
    required this.collectionId,
    this.animate = false,
  });

  final String text;

  /// A different collection's name is never animated.
  final String? collectionId;

  /// Whether a change of [text] to this value plays the reveal.
  final bool animate;

  static const duration = Duration(milliseconds: 1800);

  @override
  State<CollectionTitle> createState() => _CollectionTitleState();
}

class _CollectionTitleState extends State<CollectionTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CollectionTitle.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _from = null);
        }
      });
  }

  /// The name the reveal starts from; null when no reveal is playing.
  String? _from;

  @override
  void didUpdateWidget(CollectionTitle old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    final reveal = widget.animate &&
        old.collectionId == widget.collectionId &&
        old.text.isNotEmpty &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (reveal) {
      _from = old.text;
      _controller.forward(from: 0);
    } else {
      _from = null;
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    if (from == null) {
      return Text(widget.text, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final style = DefaultTextStyle.of(context).style;
    final accent = AppDecor.of(context).onBarButtonOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      Size sizeOf(String text) => (TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout())
              .size;
      final fromSize = sizeOf(from);
      final toSize = sizeOf(widget.text);
      final fromWidth = math.min(fromSize.width, constraints.maxWidth);
      final toWidth = math.min(toSize.width, constraints.maxWidth);
      // The measured line, not one worked out from the font size: the top
      // bar's title style may have no font size, and the bar lets its title
      // be any height, so an unset height centred the letters at NaN and
      // the whole title row drew nothing (owner's phone, 2026-10-19).
      final height = math.max(fromSize.height, toSize.height) + 4;
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final widthT =
              Curves.easeInOutCubic.transform(_interval(t, 0.1, 0.8));
          return SizedBox(
            width: fromWidth + (toWidth - fromWidth) * widthT,
            height: height,
            child: ClipRect(
              clipper: const _SidesClipper(),
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: 0,
                maxWidth: double.infinity,
                child: Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [
                    _letters(from, style, t, leaving: true, accent: accent),
                    _letters(widget.text, style, t,
                        leaving: false, accent: accent),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  /// [text]'s letters at moment [t] of the reveal: the old name going
  /// ([leaving]) or the new one coming, each on a swirl float (owner,
  /// 2026-10-19): it drifts along an S-curve while it scales and fades. The old letters float up and away, the new ones float up into
  /// place from below; the first new letters come while the last old ones
  /// are still going, so the title is never empty.
  Widget _letters(String text, TextStyle style, double t,
      {required bool leaving, required Color accent}) {
    final letters = text.characters.toList();
    final n = letters.length;
    final settled = style.color ?? Colors.black;
    // The same drift for a letter on every frame, a new one per name.
    final random = math.Random(Object.hash(text, leaving));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++)
          () {
            final dx = (random.nextDouble() * 2 - 1) * _maxDrift;
            final dy = (0.6 + random.nextDouble() * 0.4) * _rise;
            final share = n <= 1 ? 0.0 : i / (n - 1);
            // 0 is the letter in place, 1 fully away. The old name goes
            // from 0 to 0.65, the new one comes from 0.12 to the end.
            final away = leaving
                ? Curves.easeInOutCubic
                    .transform(_interval(t, share * 0.25, share * 0.25 + 0.4))
                : 1 -
                    Curves.easeInOutCubic.transform(_interval(
                        t, 0.12 + share * 0.4, 0.12 + share * 0.4 + 0.48));
            final offset = _swirl(away, dx, leaving ? -dy : dy);
            final color = leaving
                ? settled
                : Color.lerp(
                    accent,
                    settled,
                    Curves.easeIn.transform(_interval(
                        t, 0.3 + share * 0.4, 0.3 + share * 0.4 + 0.3)))!;
            // No blur: an ImageFiltered letter makes its own layers, and on
            // an Android phone (Mi A2 Lite, Impeller) the whole title row
            // then drew nothing for the reveal (owner, 2026-10-19).
            final letter =
                Text(letters[i], style: style.copyWith(color: color));
            return Opacity(
              opacity: (1 - away).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: offset,
                child: Transform.scale(scale: 1 - 0.5 * away, child: letter),
              ),
            );
          }(),
      ],
    );
  }

  /// How far a letter floats up or down, and sideways at most.
  static const _rise = 22.0;
  static const _maxDrift = 14.0;

  /// The swirl's S-curve: [away] from 0 (in place) to 1 (at ([dx], [dy])),
  /// with a sideways swing that is widest halfway.
  static Offset _swirl(double away, double dx, double dy) {
    final swing = math.sin(away * math.pi * 2) * 0.7 * 4 * away * (1 - away);
    return Offset(dx * away + dx * swing, dy * away);
  }

  static double _interval(double t, double begin, double end) =>
      ((t - begin) / (end - begin)).clamp(0.0, 1.0);
}

/// Clips the title's sides only, so the width can ease while the letters
/// float above and below the line.
class _SidesClipper extends CustomClipper<Rect> {
  const _SidesClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -size.height * 2, size.width, size.height * 3);

  @override
  bool shouldReclip(_SidesClipper oldClipper) => false;
}
