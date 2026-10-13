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
    this.reveal = false,
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

  /// The line has just replaced the full row: the text glides in and the
  /// part after the dash follows it.
  final bool reveal;

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
      child: reveal
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 560),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => _line(base, v),
            )
          : _line(base, 1),
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

/// A word row that turns into its one line ([line]) while [compact], and
/// back into the full row ([full]) after. The card's height glides between
/// the two while one fades and scales into the other, and the rows change
/// one after another from the top of the screen down, like a wave.
class WordRowMorph extends StatefulWidget {
  const WordRowMorph({
    super.key,
    required this.index,
    required this.compact,
    required this.full,
    required this.line,
  });

  static const duration = Duration(milliseconds: 420);

  /// The delay of a row at the bottom of the screen; a row at the top starts
  /// at once.
  static const maxStagger = Duration(milliseconds: 240);

  final int index;
  final bool compact;
  final Widget full;

  /// Builds the one line; `reveal` is true when it replaces the full row.
  final Widget Function(bool reveal) line;

  @override
  State<WordRowMorph> createState() => _WordRowMorphState();
}

class _WordRowMorphState extends State<WordRowMorph>
    with TickerProviderStateMixin {
  /// What is shown now; follows [WordRowMorph.compact] after the row's turn
  /// in the wave. A row first built while compact is a line at once.
  late bool _compact = widget.compact;

  /// The line replaced the full row (rather than being built as a line).
  bool _morphed = false;

  /// Runs out the row's turn in the wave. A ticker, not a timer, so the
  /// wait is a frame-driven animation like the morph itself.
  late final AnimationController _wait;

  /// The morph toward [_compact], 0 to 1: the card's glide from
  /// [_fromHeight], and the fade and scale from one child into the other.
  late final AnimationController _morph;
  double? _fromHeight;

  @override
  void initState() {
    super.initState();
    _wait = AnimationController(vsync: this);
    _morph = AnimationController(
        vsync: this, duration: WordRowMorph.duration, value: 1);
    // At rest as the full row, the line is dropped.
    _morph.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_compact && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(WordRowMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact == oldWidget.compact) return;
    _wait.stop();
    final target = widget.compact;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.compact != target) return;
      _wait.duration = _turn();
      _wait.forward(from: 0).then((_) {
        if (!mounted || widget.compact != target || _compact == target) return;
        // The card's height as last laid out; it may be marked dirty
        // already, which `context.size` refuses.
        final box = context.findRenderObject();
        final from = box is RenderBox && box.hasSize ? box.size.height : null;
        setState(() {
          _fromHeight = from;
          _compact = target;
          _morphed = true;
        });
        _morph.forward(from: 0);
      });
    });
  }

  /// The row's turn: how far down the screen it is, as a share of
  /// [WordRowMorph.maxStagger].
  Duration _turn() {
    final box = context.findRenderObject();
    final screen = MediaQuery.sizeOf(context).height;
    if (box is! RenderBox || !box.hasSize || !box.attached || screen <= 0) {
      return Duration.zero;
    }
    final y = box.localToGlobal(Offset.zero).dy;
    return WordRowMorph.maxStagger * (y / screen).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _wait.dispose();
    _morph.dispose();
    super.dispose();
  }

  static const _fade = Interval(0.25, 1, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    // The full row stays mounted under its line, hidden: turning back is a
    // fade, not building every field again. Each child is drawn once into
    // its own layer and then only faded, scaled and clipped.
    final full = RepaintBoundary(child: widget.full);
    final line = _compact || _morph.isAnimating
        ? RepaintBoundary(child: widget.line(_morphed))
        : null;
    return AnimatedBuilder(
      animation: _morph,
      builder: (context, _) {
        final t = _morph.value;
        // The child being shown comes in over [t]; the other leaves over it.
        final coming = _fade.transform(t);
        final going = _fade.transform(1 - t);
        double grow(double begin, double v) =>
            lerpDouble(begin, 1, Curves.easeOutBack.transform(v))!;
        return _MorphLayout(
          toLine: _compact,
          from: _fromHeight,
          glide: Curves.easeInOutCubic.transform(t),
          fullOpacity: _compact ? going : coming,
          lineOpacity: _compact ? coming : going,
          fullScale: grow(0.97, _compact ? 1 - t : t),
          lineScale: grow(0.92, _compact ? t : 1 - t),
          full: full,
          line: line,
        );
      },
    );
  }
}

enum _Slot { full, line }

/// Lays out the full row and, while there is one, its line, both from the
/// top; is as tall as the one being shown, gliding there from [from] over
/// [glide]; and paints each at its opacity and scale, clipped to its own
/// height while it glides. Only the one being shown takes touches and is
/// read by a screen reader; a child at opacity 0 is not painted and counts
/// as offstage.
class _MorphLayout
    extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _MorphLayout({
    required this.toLine,
    required this.from,
    required this.glide,
    required this.fullOpacity,
    required this.lineOpacity,
    required this.fullScale,
    required this.lineScale,
    required this.full,
    required this.line,
  });

  final bool toLine;
  final double? from;
  final double glide;
  final double fullOpacity;
  final double lineOpacity;
  final double fullScale;
  final double lineScale;
  final Widget full;
  final Widget? line;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) => switch (slot) {
        _Slot.full => full,
        _Slot.line => line,
      };

  @override
  SlottedRenderObjectElement<_Slot, RenderBox> createElement() =>
      _MorphElement(this);

  @override
  _RenderMorph createRenderObject(BuildContext context) => _RenderMorph()
    ..toLine = toLine
    ..from = from
    ..glide = glide
    ..fullOpacity = fullOpacity
    ..lineOpacity = lineOpacity
    ..fullScale = fullScale
    ..lineScale = lineScale;

  @override
  void updateRenderObject(BuildContext context, _RenderMorph renderObject) {
    renderObject
      ..toLine = toLine
      ..from = from
      ..glide = glide
      ..fullOpacity = fullOpacity
      ..lineOpacity = lineOpacity
      ..fullScale = fullScale
      ..lineScale = lineScale;
  }
}

class _MorphElement extends SlottedRenderObjectElement<_Slot, RenderBox> {
  _MorphElement(_MorphLayout super.widget);

  /// A child at opacity 0 is offstage, as for `Offstage`: finders skip it.
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final layout = widget as _MorphLayout;
    visitChildren((child) {
      final opacity =
          child.slot == _Slot.full ? layout.fullOpacity : layout.lineOpacity;
      if (opacity > 0) visitor(child);
    });
  }
}

class _RenderMorph extends RenderBox
    with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  RenderBox? get _full => childForSlot(_Slot.full);
  RenderBox? get _line => childForSlot(_Slot.line);

  /// The child being shown: the line while [toLine] and there is one.
  RenderBox? get _shown => toLine ? (_line ?? _full) : _full;

  bool _toLine = false;
  bool get toLine => _toLine;
  set toLine(bool value) {
    if (value == _toLine) return;
    _toLine = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  double? _from;
  set from(double? value) {
    if (value == _from) return;
    _from = value;
    markNeedsLayout();
  }

  double _glide = 1;
  set glide(double value) {
    if (value == _glide) return;
    _glide = value;
    markNeedsLayout();
  }

  double _fullOpacity = 1;
  set fullOpacity(double value) {
    if (value == _fullOpacity) return;
    _fullOpacity = value;
    markNeedsPaint();
  }

  double _lineOpacity = 0;
  set lineOpacity(double value) {
    if (value == _lineOpacity) return;
    _lineOpacity = value;
    markNeedsPaint();
  }

  double _fullScale = 1;
  set fullScale(double value) {
    if (value == _fullScale) return;
    _fullScale = value;
    markNeedsPaint();
  }

  double _lineScale = 1;
  set lineScale(double value) {
    if (value == _lineScale) return;
    _lineScale = value;
    markNeedsPaint();
  }

  bool get _gliding => _from != null && _glide < 1;

  @override
  void performLayout() {
    // Laid out again only when they change: a hidden, settled full row
    // costs nothing per frame.
    // Both as wide as the row, one over the other.
    final child = constraints.hasBoundedWidth
        ? constraints.copyWith(minWidth: constraints.maxWidth)
        : constraints;
    _full?.layout(child, parentUsesSize: true);
    _line?.layout(child, parentUsesSize: true);
    final shown = _shown;
    final height = shown == null ? 0.0 : shown.size.height;
    final from = _from;
    size = constraints.constrain(Size(constraints.maxWidth,
        _gliding ? lerpDouble(from, height, _glide)! : height));
  }

  final _clip = LayerHandle<ClipRectLayer>();
  final _fullLayers =
      (LayerHandle<OpacityLayer>(), LayerHandle<TransformLayer>());
  final _lineLayers =
      (LayerHandle<OpacityLayer>(), LayerHandle<TransformLayer>());

  @override
  void paint(PaintingContext context, Offset offset) {
    // While it glides, the taller child hangs below and is clipped.
    if (_gliding) {
      _clip.layer = context.pushClipRect(
          needsCompositing, offset, Offset.zero & size, _paintChildren,
          oldLayer: _clip.layer);
    } else {
      _clip.layer = null;
      _paintChildren(context, offset);
    }
  }

  void _paintChildren(PaintingContext context, Offset offset) {
    _paintChild(context, offset, _full, _fullOpacity, _fullScale,
        Alignment.topCenter, _fullLayers);
    _paintChild(context, offset, _line, _lineOpacity, _lineScale,
        Alignment.centerLeft, _lineLayers);
  }

  void _paintChild(
    PaintingContext context,
    Offset offset,
    RenderBox? child,
    double opacity,
    double scale,
    Alignment alignment,
    (LayerHandle<OpacityLayer>, LayerHandle<TransformLayer>) layers,
  ) {
    final (opacityLayer, transformLayer) = layers;
    if (child == null || opacity <= 0) {
      opacityLayer.layer = null;
      transformLayer.layer = null;
      return;
    }
    void scaled(PaintingContext context, Offset offset) {
      if (scale == 1) {
        transformLayer.layer = null;
        context.paintChild(child, offset);
        return;
      }
      final origin = alignment.alongSize(child.size);
      final transform = Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(
            origin.dx * (1 - scale), origin.dy * (1 - scale), 0);
      transformLayer.layer = context.pushTransform(needsCompositing, offset,
          transform, (context, offset) => context.paintChild(child, offset),
          oldLayer: transformLayer.layer);
    }

    if (opacity >= 1) {
      opacityLayer.layer = null;
      scaled(context, offset);
    } else {
      opacityLayer.layer = context.pushOpacity(
          offset, (opacity * 255).round(), scaled,
          oldLayer: opacityLayer.layer);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _shown?.hitTest(result, position: position) ?? false;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final shown = _shown;
    if (shown != null) visitor(shown);
  }

  @override
  void dispose() {
    _clip.layer = null;
    _fullLayers.$1.layer = null;
    _fullLayers.$2.layer = null;
    _lineLayers.$1.layer = null;
    _lineLayers.$2.layer = null;
    super.dispose();
  }
}
