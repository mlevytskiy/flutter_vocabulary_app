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

  /// The card's glide from [_fromHeight] to the shown child's height.
  late final AnimationController _morph;
  double? _fromHeight;

  @override
  void initState() {
    super.initState();
    _wait = AnimationController(vsync: this);
    _morph = AnimationController(
        vsync: this, duration: WordRowMorph.duration, value: 1);
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

  @override
  Widget build(BuildContext context) {
    final switcher = AnimatedSwitcher(
      duration: WordRowMorph.duration,
      // Only the shown child sizes the row; the leaving one is laid over it
      // from the top and clipped as the card glides to the new height.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [
          for (final child in previous)
            Positioned(left: 0, right: 0, top: 0, child: child),
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, animation) {
        final line = child.key == const ValueKey('line');
        final fade = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.25, 1, curve: Curves.easeOut),
        );
        final scale = Tween<double>(begin: line ? 0.92 : 0.97, end: 1)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            alignment: line ? Alignment.centerLeft : Alignment.topCenter,
            child: child,
          ),
        );
      },
      child: _compact
          ? KeyedSubtree(
              key: const ValueKey('line'), child: widget.line(_morphed))
          : KeyedSubtree(key: const ValueKey('full'), child: widget.full),
    );
    return AnimatedBuilder(
      animation: _morph,
      builder: (context, child) => _GlideHeight(
        from: _fromHeight,
        t: Curves.easeInOutCubic.transform(_morph.value),
        child: child,
      ),
      child: switcher,
    );
  }
}

/// Sizes its child's width as the child, and its height between [from] and
/// the child's own height at [t], clipping what is below while it glides.
/// With [from] null, or at [t] 1, it is exactly the child.
class _GlideHeight extends SingleChildRenderObjectWidget {
  const _GlideHeight({required this.from, required this.t, super.child});

  final double? from;
  final double t;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlideHeight(from, t);

  @override
  void updateRenderObject(BuildContext context, _RenderGlideHeight renderObject) {
    renderObject
      ..from = from
      ..t = t;
  }
}

class _RenderGlideHeight extends RenderProxyBox {
  _RenderGlideHeight(this._from, this._t);

  double? _from;
  set from(double? value) {
    if (value == _from) return;
    _from = value;
    markNeedsLayout();
  }

  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsLayout();
  }

  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints, parentUsesSize: true);
    final height = child.size.height;
    final from = _from;
    size = constraints.constrain(Size(child.size.width,
        from == null || _t >= 1 ? height : lerpDouble(from, height, _t)!));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    // Settled, the child is drawn as it is; while gliding, the leaving
    // child hangs below the shown one and is clipped at the card's height.
    if (_t >= 1 || _from == null) {
      _clip.layer = null;
      context.paintChild(child, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
        needsCompositing, offset, Offset.zero & size, super.paint,
        oldLayer: _clip.layer);
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}
