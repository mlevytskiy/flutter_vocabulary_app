import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/providers.dart' show WordDetailMode;
import '../../../core/widgets/hidden_field_text.dart';

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
    this.hideWord = false,
    this.hideDetail = false,
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

  /// The word, or the detail, is drawn transparent: [WordRowMorph] is
  /// flying it in from the full row.
  final bool hideWord;
  final bool hideDetail;

  /// The whole line, as a screen reader and a test read it.
  String get text {
    final w = word.trim();
    if (detail.isEmpty) return w;
    if (w.isEmpty) return detail;
    return '$w$separator$detail';
  }

  /// Where the word, and the detail, sit in the line's text; empty when the
  /// line has none.
  static TextRange wordRange(String word) =>
      TextRange(start: 0, end: word.trim().length);
  static TextRange detailRange(String word, String detail) {
    final w = word.trim();
    final start = w.isEmpty ? 0 : w.length + separator.length;
    return detail.isEmpty
        ? TextRange.empty
        : TextRange(start: start, end: start + detail.length);
  }

  static const _wordColor = Color(0xFF3B2470);
  static const _detailColor = Color(0xFF5E5470);

  static TextStyle _base(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);

  /// How the line draws a typed word, and the detail.
  static TextStyle wordStyle(BuildContext context) =>
      _base(context).copyWith(fontWeight: FontWeight.w600, color: _wordColor);
  static TextStyle detailStyle(BuildContext context) =>
      _base(context).copyWith(color: _detailColor);

  @override
  Widget build(BuildContext context) {
    final w = word.trim();
    Color shown(Color color, bool hidden) =>
        hidden ? color.withValues(alpha: 0) : color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(14, 12, 14 + endInset, 12),
      decoration: BoxDecoration(
        color: const Color(0x57d9c1ff),
        borderRadius: BorderRadius.circular(12),
      ),
      foregroundDecoration: highlight,
      child: Text.rich(
        TextSpan(children: [
          if (w.isNotEmpty || detail.isEmpty)
            TextSpan(
              text: w.isEmpty ? '—' : w,
              style: wordStyle(context).copyWith(
                color: w.isEmpty
                    ? const Color(0x803B2470)
                    : shown(_wordColor, hideWord),
              ),
            ),
          if (w.isNotEmpty && detail.isNotEmpty)
            TextSpan(text: separator, style: detailStyle(context)),
          if (detail.isNotEmpty)
            TextSpan(
              text: detail,
              style: detailStyle(context)
                  .copyWith(color: shown(_detailColor, hideDetail)),
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
///
/// The texts move rather than fade, like a local hero: the word flies from
/// its field ([word]) to the start of the line, and the translation
/// ([detail]) from its field to its place after the dash, each turning into
/// the line's style on the way.
class WordRowMorph extends StatefulWidget {
  const WordRowMorph({
    super.key,
    required this.index,
    required this.openness,
    required this.full,
    required this.line,
    this.word,
    this.detail,
  });

  /// The share of the panel's slide to half-open by which a row at the
  /// bottom of the screen starts after one at the top.
  static const stagger = 0.3;

  final int index;

  /// The photo panel's openness: 0 closed, 0.5 half-open and beyond.
  final Animation<double> openness;
  final Widget full;

  /// Builds the one line, with the texts that are flying hidden.
  final Widget Function(bool hideWord, bool hideDetail) line;

  /// The full row's Word field, whose text flies to the line's word.
  final TextEditingController? word;

  /// The full row's field whose text is the line's detail (the
  /// translation), or null when the detail only fades (a definition, which
  /// is usually several lines).
  final TextEditingController? detail;

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
      _fields.clear();
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

  /// The fields found while the row moves; dropped when it rests.
  final _fields = <TextEditingController, RenderEditable>{};

  /// The drawn field of [controller] in the full row, found by walking the
  /// row's elements once per move; null when it is not there.
  RenderEditable? _fieldOf(TextEditingController controller) {
    final known = _fields[controller];
    if (known != null && known.attached) return known;
    RenderEditable? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement &&
          element.state is EditableTextState &&
          (element.widget as EditableText).controller == controller) {
        found = (element.state as EditableTextState).renderEditable;
        return;
      }
      element.visitChildren(visit);
    }

    if (mounted) (context as Element).visitChildren(visit);
    if (found case final field?) _fields[controller] = field;
    return found;
  }

  /// The texts that fly in this frame: each one typed in its field and
  /// shown on the line.
  List<_Flight> _flights(String detail) {
    final fieldStyle =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final word = widget.word;
    final detailField = widget.detail;
    final w = word?.text.trim() ?? '';
    return [
      if (word != null && w.isNotEmpty)
        _Flight(
          isWord: true,
          text: w,
          field: () => _fieldOf(word),
          fieldRange: _rangeOf(word.text, w),
          lineRange: CompactWordLine.wordRange(w),
          from: fieldStyle,
          to: CompactWordLine.wordStyle(context),
        ),
      if (detailField != null && detail.isNotEmpty)
        _Flight(
          isWord: false,
          text: detail,
          field: () => _fieldOf(detailField),
          fieldRange: _rangeOf(detailField.text, detail),
          lineRange: CompactWordLine.detailRange(w, detail),
          from: fieldStyle,
          to: CompactWordLine.detailStyle(context),
        ),
    ];
  }

  static TextRange _rangeOf(String text, String trimmed) {
    final start = text.indexOf(trimmed);
    return TextRange(start: start, end: start + trimmed.length);
  }

  static const _fade = Interval(0.25, 1, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final moving = t > 0 && t < 1;
    final detail = widget.detail?.text.trim() ?? '';
    final flights = moving ? _flights(detail) : const <_Flight>[];
    final flyWord = flights.any((f) => f.isWord);
    final flyDetail = flights.any((f) => !f.isWord);
    // Each card as AnimatedSwitcher drew it: the one coming in fades in
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
      flights: flights,
      full: t < 1
          ? part(
              KeyedSubtree(
                key: const ValueKey('full'),
                child: HiddenFieldText(
                  controllers: {
                    if (flyWord) widget.word!,
                    if (flyDetail) widget.detail!,
                  },
                  child: widget.full,
                ),
              ),
              1 - t,
              0.97,
              Alignment.topCenter)
          : null,
      line: t > 0
          ? part(
              KeyedSubtree(
                  key: const ValueKey('line'),
                  child: widget.line(flyWord, flyDetail)),
              t,
              0.92,
              Alignment.centerLeft)
          : null,
    );
  }
}

/// One text flying between its field in the full row and its place on the
/// line: [fieldRange] of the field's text, [lineRange] of the line's.
class _Flight {
  const _Flight({
    required this.isWord,
    required this.text,
    required this.field,
    required this.fieldRange,
    required this.lineRange,
    required this.from,
    required this.to,
  });

  /// The word, or else the detail.
  final bool isWord;
  final String text;
  final RenderEditable? Function() field;
  final TextRange fieldRange;
  final TextRange lineRange;
  final TextStyle from;
  final TextStyle to;
}

enum _Part { full, line }

/// The full row and its line laid over each other from the top; the card is
/// the full row's height at [t] 0 and the line's at 1, clipping what hangs
/// below while it glides, and the [flights] drawn over both. Either child
/// may be missing.
class _Morph extends SlottedMultiChildRenderObjectWidget<_Part, RenderBox> {
  const _Morph({
    required this.t,
    required this.flights,
    this.full,
    this.line,
  });

  final double t;
  final List<_Flight> flights;
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
  _RenderMorph createRenderObject(BuildContext context) =>
      _RenderMorph(t, flights, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderMorph renderObject) {
    renderObject
      ..t = t
      ..flights = flights
      ..textDirection = Directionality.of(context);
  }
}

class _RenderMorph extends RenderBox
    with SlottedContainerRenderObjectMixin<_Part, RenderBox> {
  _RenderMorph(this._t, this._flights, this._textDirection);

  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsLayout();
  }

  List<_Flight> _flights;
  set flights(List<_Flight> value) {
    if (identical(value, _flights)) return;
    _flights = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
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
    void paintAll(PaintingContext context, Offset offset) {
      if (_full case final full?) context.paintChild(full, offset);
      if (_line case final line?) context.paintChild(line, offset);
      if (_gliding) _paintFlights(context.canvas, offset);
    }

    if (!_gliding) {
      _clip.layer = null;
      paintAll(context, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
        needsCompositing, offset, Offset.zero & size, paintAll,
        oldLayer: _clip.layer);
  }

  /// The line's text, found in the line's render tree.
  RenderParagraph? _lineText() {
    RenderParagraph? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is RenderParagraph) {
        found = child;
        return;
      }
      child.visitChildren(visit);
    }

    _line?.visitChildren(visit);
    return found;
  }

  /// [range]'s box in [text], in this box's coordinates; null when nothing
  /// of it is laid out.
  Rect? _boxOf(RenderBox text, TextRange range,
      List<TextBox> Function(TextSelection) boxes) {
    if (!text.attached || !text.hasSize || !range.isValid) return null;
    final found =
        boxes(TextSelection(baseOffset: range.start, extentOffset: range.end));
    if (found.isEmpty) return null;
    var rect = found.first.toRect();
    for (final box in found.skip(1)) {
      rect = rect.expandToInclude(box.toRect());
    }
    return MatrixUtils.transformRect(text.getTransformTo(this), rect);
  }

  void _paintFlights(Canvas canvas, Offset offset) {
    if (_flights.isEmpty) return;
    final line = _lineText();
    if (line == null) return;
    final t = _t;
    for (final flight in _flights) {
      final field = flight.field();
      if (field == null) continue;
      final from = _boxOf(field, flight.fieldRange, field.getBoxesForSelection);
      final to = _boxOf(line, flight.lineRange, line.getBoxesForSelection);
      if (from == null || to == null) continue;
      // The line's room for the text: up to its end, before the panel.
      final lineEnd = MatrixUtils.transformPoint(
              line.getTransformTo(this), Offset(line.size.width, 0))
          .dx;
      final painter = TextPainter(
        text: TextSpan(
            text: flight.text,
            style: TextStyle.lerp(flight.from, flight.to, t)),
        textDirection: _textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(
          maxWidth: math.max(1,
              lerpDouble(from.width + 1, math.max(lineEnd - to.left, 1), t)!),
        );
      final left = lerpDouble(from.left, to.left, t)!;
      final centre = lerpDouble(from.center.dy, to.center.dy, t)!;
      painter.paint(canvas, offset + Offset(left, centre - painter.height / 2));
      painter.dispose();
    }
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

