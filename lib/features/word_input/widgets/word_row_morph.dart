import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/providers.dart' show WordDetailMode;

/// The text after the dash on a row's one line while the photo panel is
/// open: the translation when the detail mode shows one and it is filled,
/// otherwise the definition (one line, its line breaks made spaces). Empty
/// when the row has neither.
String compactDetail({
  required WordDetailMode mode,
  required String translation,
  required String definition,
}) {
  final t = translation.trim();
  if (mode != WordDetailMode.definition && t.isNotEmpty) return t;
  return definition.trim().replaceAll(RegExp(r'\s*\n\s*'), ' ');
}

/// One word row as a single line of text, "word — translation", shown while
/// the photo panel is open (the panel makes the main screen only for
/// looking). Drawn on the row's own card colour, and highlighted like the
/// full row when its photo is selected.
class CompactWordLine extends StatelessWidget {
  const CompactWordLine({
    super.key,
    required this.index,
    required this.word,
    required this.detail,
    this.highlight,
    this.endInset = 0,
    this.reveal = 1,
  });

  static const separator = ' — ';

  final int index;
  final String word;

  /// See [compactDetail]; empty draws the word alone.
  final String detail;

  /// The selected photo's row highlight, or null.
  final Decoration? highlight;

  /// Kept free at the line's end, so the text ends beside the half-open
  /// panel instead of under it.
  final double endInset;

  /// How far the text has come in, 0 to 1, as the line replaces the full
  /// row: it glides in and the part after the dash follows it.
  final double reveal;

  /// The whole line, as a screen reader and a test read it.
  String get text {
    final w = word.trim();
    if (detail.isEmpty) return w;
    if (w.isEmpty) return detail;
    return '$w$separator$detail';
  }

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(14, 12, 14 + endInset, 12),
      decoration: BoxDecoration(
        color: const Color(0x57d9c1ff),
        borderRadius: BorderRadius.circular(12),
      ),
      foregroundDecoration: highlight,
      child: _line(base, Curves.easeOutCubic.transform(reveal)),
    );
  }

  /// The text at reveal progress [v]: the line slides in from the left, and
  /// the dash and detail fade in over the second half.
  Widget _line(TextStyle base, double v) {
    final w = word.trim();
    final detailOpacity = ((v - 0.35) / 0.65).clamp(0.0, 1.0);
    const wordColor = Color(0xFF3B2470);
    final detailColor =
        const Color(0xFF5E5470).withValues(alpha: detailOpacity);
    return Transform.translate(
      offset: Offset(-14 * (1 - v), 0),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: w.isEmpty && detail.isEmpty ? '—' : w,
            style: base.copyWith(
              fontWeight: FontWeight.w600,
              color: w.isEmpty ? const Color(0x803B2470) : wordColor,
            ),
          ),
          if (detail.isNotEmpty)
            TextSpan(
              text: w.isEmpty ? detail : '$separator$detail',
              style: base.copyWith(color: detailColor),
            ),
        ]),
        semanticsLabel: text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A word row that turns into its one line ([line]) as the photo panel
/// opens, and back into the full row ([full]) as it closes, following the
/// panel's [openness] frame by frame: on a tap they move together, and on a
/// drag the rows follow the finger. The card's height glides between the two
/// while one fades and scales into the other, and the rows change one after
/// another from the top of the screen down, like a wave (back up on close).
class WordRowMorph extends StatefulWidget {
  const WordRowMorph({
    super.key,
    required this.index,
    required this.openness,
    required this.full,
    required this.line,
  });

  /// The share of the panel's slide to half-open by which a row at the
  /// bottom of the screen starts after one at the top.
  static const stagger = 0.3;

  final int index;

  /// The photo panel's openness: 0 closed, 0.5 half-open and beyond.
  final Animation<double> openness;
  final Widget full;

  /// Builds the one line; `reveal` is how far its text has come in, 0 to 1.
  final Widget Function(double reveal) line;

  @override
  State<WordRowMorph> createState() => _WordRowMorphState();
}

class _WordRowMorphState extends State<WordRowMorph> {
  /// 0 the full row, 1 the line.
  late double _t;

  /// The row's turn in the wave, a share of the slide; measured when the
  /// panel starts to move and kept until it rests closed or open.
  double? _turn;

  @override
  void initState() {
    super.initState();
    _t = _progress(widget.openness.value);
    widget.openness.addListener(_onOpenness);
  }

  @override
  void didUpdateWidget(WordRowMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openness != widget.openness) {
      oldWidget.openness.removeListener(_onOpenness);
      widget.openness.addListener(_onOpenness);
      _t = _progress(widget.openness.value);
    }
  }

  @override
  void dispose() {
    widget.openness.removeListener(_onOpenness);
    super.dispose();
  }

  void _onOpenness() {
    final t = _progress(widget.openness.value);
    if (t != _t) setState(() => _t = t);
  }

  /// The row's morph at panel [openness]: its part of the way to half-open.
  double _progress(double openness) {
    final half = (openness / 0.5).clamp(0.0, 1.0);
    if (half == 0 || half == 1) {
      _turn = null;
      return half;
    }
    final turn = _turn ??= _measureTurn();
    return ((half - turn) / (1 - WordRowMorph.stagger)).clamp(0.0, 1.0);
  }

  /// How far down the screen the row is, as a share of the stagger; a row
  /// not laid out yet goes first.
  double _measureTurn() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return 0;
    final screen = MediaQuery.maybeSizeOf(context)?.height ?? 0;
    if (screen <= 0) return 0;
    final y = box.localToGlobal(Offset.zero).dy;
    return WordRowMorph.stagger * (y / screen).clamp(0.0, 1.0);
  }

  static const _fade = Interval(0.25, 1, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    // Each child as AnimatedSwitcher drew it: the one coming in fades in
    // late and scales up with a little overshoot; the one leaving does the
    // same backwards. Behind a boundary the row's fields and text are
    // recorded once and only moved.
    Widget part(Widget child, double v, double from, Alignment alignment) =>
        Opacity(
          opacity: _fade.transform(v),
          child: Transform.scale(
            scale: from + (1 - from) * Curves.easeOutBack.transform(v),
            alignment: alignment,
            child: RepaintBoundary(child: child),
          ),
        );
    return _Morph(
      t: Curves.easeInOutCubic.transform(t),
      full: t < 1
          ? part(KeyedSubtree(key: const ValueKey('full'), child: widget.full),
              1 - t, 0.97, Alignment.topCenter)
          : null,
      line: t > 0
          ? part(
              KeyedSubtree(key: const ValueKey('line'), child: widget.line(t)),
              t,
              0.92,
              Alignment.centerLeft)
          : null,
    );
  }
}

enum _Part { full, line }

/// The full row and its line laid over each other from the top; the card is
/// the full row's height at [t] 0 and the line's at 1, clipping what hangs
/// below while it glides. Either child may be missing.
class _Morph extends SlottedMultiChildRenderObjectWidget<_Part, RenderBox> {
  const _Morph({required this.t, this.full, this.line});

  final double t;
  final Widget? full;
  final Widget? line;

  @override
  Iterable<_Part> get slots => _Part.values;

  @override
  Widget? childForSlot(_Part slot) => switch (slot) {
        _Part.full => full,
        _Part.line => line,
      };

  @override
  _RenderMorph createRenderObject(BuildContext context) => _RenderMorph(t);

  @override
  void updateRenderObject(BuildContext context, _RenderMorph renderObject) {
    renderObject.t = t;
  }
}

class _RenderMorph extends RenderBox
    with SlottedContainerRenderObjectMixin<_Part, RenderBox> {
  _RenderMorph(this._t);

  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsLayout();
  }

  RenderBox? get _full => childForSlot(_Part.full);
  RenderBox? get _line => childForSlot(_Part.line);

  final _clip = LayerHandle<ClipRectLayer>();

  bool get _gliding => _full != null && _line != null;

  /// The card for children of sizes [full] and [line] (either may be null).
  Size _sizeFor(BoxConstraints constraints, Size? full, Size? line) {
    final width = math.max(full?.width ?? 0, line?.width ?? 0);
    final height = full != null && line != null
        ? lerpDouble(full.height, line.height, _t)!
        : (full ?? line)?.height ?? 0;
    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints,
      _full?.getDryLayout(constraints), _line?.getDryLayout(constraints));

  @override
  void performLayout() {
    // Laid out again with the same constraints, a child that has not
    // changed returns at once: only the card's height moves.
    final full = _full;
    final line = _line;
    full?.layout(constraints, parentUsesSize: true);
    line?.layout(constraints, parentUsesSize: true);
    size = _sizeFor(constraints, full?.size, line?.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void paintChildren(PaintingContext context, Offset offset) {
      if (_full case final full?) context.paintChild(full, offset);
      if (_line case final line?) context.paintChild(line, offset);
    }

    if (!_gliding) {
      _clip.layer = null;
      paintChildren(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
        needsCompositing, offset, Offset.zero & size, paintChildren,
        oldLayer: _clip.layer);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // The full row first: it is what a closing row becomes.
    for (final child in [_full, _line]) {
      if (child != null && child.hitTest(result, position: position)) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}
