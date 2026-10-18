import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_decor.dart';

/// The main screen's title: the collection's name on one line (collection-
/// naming, owner 2026-10-18). When the AI's name replaces "Vocabulary N" on
/// screen ([animate] true for that change), the old letters sink and fade
/// away left to right, then the new ones rise into place one after another,
/// each coming into focus and settling from the top bar's button colour to
/// the title colour, while the title's width eases to the new one. Any other
/// change, and every change with animations turned off, is shown at once.
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

  static const duration = Duration(milliseconds: 1500);

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
      double widthOf(String text) => (TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout())
              .width;
      final fromWidth = math.min(widthOf(from), constraints.maxWidth);
      final toWidth = math.min(widthOf(widget.text), constraints.maxWidth);
      final height = style.fontSize == null
          ? null
          : scaler.scale(style.fontSize!) * (style.height ?? 1.3) + 4;
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final widthT =
              Curves.easeInOutCubic.transform(_interval(t, 0.15, 0.7));
          return SizedBox(
            width: fromWidth + (toWidth - fromWidth) * widthT,
            height: height,
            child: ClipRect(
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
  /// ([leaving]) or the new one coming.
  Widget _letters(String text, TextStyle style, double t,
      {required bool leaving, required Color accent}) {
    final letters = text.characters.toList();
    final n = letters.length;
    final settled = style.color ?? Colors.black;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < n; i++)
          () {
            final share = n <= 1 ? 0.0 : i / (n - 1);
            // The old name goes in the first quarter, the new one comes
            // from 0.2 on, each letter a little after the one before.
            final p = leaving
                ? Curves.easeInCubic
                    .transform(_interval(t, share * 0.16, share * 0.16 + 0.14))
                : Curves.easeOutCubic.transform(
                    _interval(t, 0.2 + share * 0.42, 0.2 + share * 0.42 + 0.3));
            final opacity = leaving ? 1 - p : p;
            final dy = leaving ? 7 * p : 9 * (1 - p);
            final blur = leaving ? 3.5 * p : 5 * (1 - p);
            final color = leaving
                ? settled
                : Color.lerp(
                    accent,
                    settled,
                    Curves.easeIn.transform(_interval(
                        t, 0.3 + share * 0.42, 0.3 + share * 0.42 + 0.25)))!;
            Widget letter =
                Text(letters[i], style: style.copyWith(color: color));
            if (blur > 0.05) {
              letter = ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: letter,
              );
            }
            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, dy), child: letter),
            );
          }(),
      ],
    );
  }

  static double _interval(double t, double begin, double end) =>
      ((t - begin) / (end - begin)).clamp(0.0, 1.0);
}
