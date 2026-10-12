import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Scrolls the word list as little as needed so that row [index] is fully in
/// view (spec AC-04); a row already in view does not move.
///
/// Rows are built lazily and have different heights, so a row far away has no
/// context yet: the list first jumps to an estimated offset (index × the
/// average height of the rows built so far), then, once the row is built,
/// `Scrollable.ensureVisible` reveals it with the smallest movement. This
/// repeats for at most [maxFrames] frames (sad §4 "Jump to a photo's rows").
Future<void> jumpToRow(
  ScrollController controller,
  int index,
  /// Row [index]'s key; null past the last row.
  GlobalKey? Function(int index) rowKey, {
  int maxFrames = 12,
  Duration duration = const Duration(milliseconds: 150),
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (!controller.hasClients) return;
    final row = rowKey(index)?.currentContext;
    if (row != null && row.mounted) {
      // Below the viewport: bring its bottom edge in; above: its top edge.
      // A row fully in view is left where it is.
      await Scrollable.ensureVisible(row,
          duration: duration,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      if (!row.mounted) return;
      await Scrollable.ensureVisible(row,
          duration: duration,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      return;
    }
    _jumpToEstimate(controller, index, rowKey);
    await WidgetsBinding.instance.endOfFrame;
  }
}

void _jumpToEstimate(
    ScrollController controller, int index, GlobalKey? Function(int index) rowKey) {
  final position = controller.position;
  // The rows built now are around the viewport: the first of them, where it
  // starts in the list, and their average height give the estimate.
  int? first;
  double? firstTop;
  var total = 0.0;
  var count = 0;
  for (var i = 0;; i++) {
    final key = rowKey(i);
    if (key == null) break; // past the last row
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) {
      if (first != null) break;
      continue;
    }
    if (first == null) {
      first = i;
      firstTop = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
    }
    total += box.size.height;
    count++;
  }
  if (first == null) return;
  final average = total / count;
  final top = firstTop! + (index - first) * average;
  // Aim as the reveal will: a row below ends at the bottom edge, a row above
  // starts at the top edge.
  final target = top > position.pixels ? top + average - position.viewportDimension : top;
  position.jumpTo(target.clamp(position.minScrollExtent, position.maxScrollExtent));
}
