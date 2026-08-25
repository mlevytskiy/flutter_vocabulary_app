import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Two [TextField]s side by side that always share the same height.
///
/// Usage inside a ListView.builder:
///
/// ```dart
/// ListView.builder(
///   itemCount: _wordControllers.length,
///   itemBuilder: (context, index) => Padding(
///     padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
///     child: SyncedTextFieldRow(
///       leftController: _wordControllers[index],
///       rightController: _translationControllers[index],
///       leftLabel: 'Word',
///       rightLabel: 'Translation',
///       leftHint: 'Word',
///       rightHint: 'Переклад',
///     ),
///   ),
/// )
/// ```
///
/// How it works: on every keystroke the text of both controllers is measured
/// with a [TextPainter] against the exact width each field will get. The larger
/// of the two line counts is passed to *both* fields as `minLines`, while
/// `maxLines` stays `null`. The taller field drives the height; the shorter one
/// is padded out to match. Each instance measures only its own two controllers,
/// so rows stay independent of each other.
class SyncedTextFieldRow extends StatefulWidget {
  const SyncedTextFieldRow({
    super.key,
    required this.leftController,
    required this.rightController,
    this.leftLabel = 'Word',
    this.rightLabel = 'Translation',
    this.leftHint,
    this.rightHint,
    this.leftFocusNode,
    this.rightFocusNode,
    this.spacing = 16,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    this.borderWidth = 1,
    this.style,
  });

  final TextEditingController leftController;
  final TextEditingController rightController;

  final String leftLabel;
  final String rightLabel;
  final String? leftHint;
  final String? rightHint;
  final FocusNode? leftFocusNode;
  final FocusNode? rightFocusNode;

  /// Horizontal gap between the two fields.
  final double spacing;

  /// Passed to both fields *and* used for measurement, so it must be explicit —
  /// relying on the framework default would make the measurement guesswork.
  final EdgeInsets contentPadding;

  /// Width of the [OutlineInputBorder] side, subtracted when measuring.
  final double borderWidth;

  /// Text style for both fields. Defaults to `bodyLarge` from the theme.
  final TextStyle? style;

  @override
  State<SyncedTextFieldRow> createState() => _SyncedTextFieldRowState();
}

class _SyncedTextFieldRowState extends State<SyncedTextFieldRow> {
  @override
  void initState() {
    super.initState();
    widget.leftController.addListener(_onTextChanged);
    widget.rightController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(SyncedTextFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leftController != widget.leftController) {
      oldWidget.leftController.removeListener(_onTextChanged);
      widget.leftController.addListener(_onTextChanged);
    }
    if (oldWidget.rightController != widget.rightController) {
      oldWidget.rightController.removeListener(_onTextChanged);
      widget.rightController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    // Only the listeners are removed here — the controllers are owned by the
    // parent (the list), so disposing them is the parent's job.
    widget.leftController.removeListener(_onTextChanged);
    widget.rightController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  /// Number of visual lines [text] occupies when wrapped at [maxWidth].
  int _lineCount(
    String text,
    TextStyle style,
    StrutStyle strutStyle,
    double maxWidth,
    TextDirection direction,
  ) {
    if (maxWidth <= 0) return 1;

    // An empty string, or one ending in a newline, can report one line fewer
    // than the field actually renders. A trailing space fixes both cases.
    final probe = (text.isEmpty || text.endsWith('\n')) ? '$text ' : text;

    final painter = TextPainter(
      text: TextSpan(text: probe, style: style),
      strutStyle: strutStyle,
      maxLines: null,
      textDirection: direction,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);

    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return math.max(1, lines);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String? hint,
    required TextStyle style,
    required StrutStyle strutStyle,
    required int minLines,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      // A forced strut keeps the rendered line height identical to what the
      // TextPainter measured, regardless of the glyphs actually typed.
      strutStyle: strutStyle,
      minLines: minLines,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderSide: BorderSide(width: widget.borderWidth),
        ),
        contentPadding: widget.contentPadding,
        isDense: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        Theme.of(context).textTheme.bodyLarge ??
        const TextStyle(fontSize: 16);
    final strutStyle = StrutStyle.fromTextStyle(style, forceStrutHeight: true);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Each Expanded gets exactly half of what's left after the gap.
        final fieldWidth = (constraints.maxWidth - widget.spacing) / 2;

        // Width actually available to the glyphs. Rounding down by a pixel is
        // deliberate: over-estimating the line count leaves both fields equally
        // (and harmlessly) tall, whereas under-estimating lets one field
        // outgrow the other — the exact bug we're fixing.
        final textWidth = fieldWidth -
            widget.contentPadding.horizontal -
            widget.borderWidth * 2 -
            1;

        final lines = math.max(
          _lineCount(widget.leftController.text, style, strutStyle, textWidth,
              direction),
          _lineCount(widget.rightController.text, style, strutStyle, textWidth,
              direction),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildField(
                controller: widget.leftController,
                label: widget.leftLabel,
                hint: widget.leftHint,
                style: style,
                strutStyle: strutStyle,
                minLines: lines,
                focusNode: widget.leftFocusNode,
              ),
            ),
            SizedBox(width: widget.spacing),
            Expanded(
              child: _buildField(
                controller: widget.rightController,
                label: widget.rightLabel,
                hint: widget.rightHint,
                style: style,
                strutStyle: strutStyle,
                minLines: lines,
                focusNode: widget.rightFocusNode,
              ),
            ),
          ],
        );
      },
    );
  }
}
