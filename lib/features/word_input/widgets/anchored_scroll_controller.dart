import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The word list's scroll controller. While the rows morph between full rows
/// and one-line rows (photo-panel-glass), [holdTopItem] keeps the item cut by
/// the list's top where it is: the same item stays on top with the same share
/// of it above the top, whatever the items above it do, and closing the panel
/// brings the list back to where it was.
///
/// After each layout of the list the position checks the held item and, if
/// it moved, corrects the scroll offset, and the list lays out again in the
/// same frame, so the item never shifts for a frame. This also covers the
/// list's own repair of its offsets for items above that were never built
/// during the morph. Scrolling by hand lets go.
class AnchoredScrollController extends ScrollController {
  /// Holds the item now cut by the list's top (or at it), until [release].
  void holdTopItem() {
    for (final position in positions) {
      if (position is _AnchoredScrollPosition) position.holdTopItem();
    }
  }

  void release() {
    for (final position in positions) {
      if (position is _AnchoredScrollPosition) position.anchor = null;
    }
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics,
          ScrollContext context, ScrollPosition? oldPosition) =>
      _AnchoredScrollPosition(
        physics: physics,
        context: context,
        initialPixels: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        oldPosition: oldPosition,
        debugLabel: debugLabel,
      );
}

/// An item of the list and the share of its height above the list's top.
typedef _Anchor = ({RenderBox item, double share});

class _AnchoredScrollPosition extends ScrollPositionWithSingleContext {
  _AnchoredScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  _Anchor? anchor;

  RenderViewportBase? _viewport() {
    final root = context.notificationContext?.findRenderObject();
    RenderViewportBase? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is RenderViewportBase) {
        found = child;
        return;
      }
      child.visitChildren(visit);
    }

    if (root != null) visit(root);
    return found;
  }

  /// The item's top, from the list's top.
  static double _topOf(RenderBox item, RenderViewportBase viewport) =>
      MatrixUtils.transformPoint(item.getTransformTo(viewport), Offset.zero).dy;

  void holdTopItem() {
    anchor = null;
    final viewport = _viewport();
    if (viewport == null || viewport.axis != Axis.vertical) return;
    RenderSliverMultiBoxAdaptor? list;
    void visit(RenderObject child) {
      if (list != null) return;
      if (child is RenderSliverMultiBoxAdaptor) {
        list = child;
        return;
      }
      child.visitChildren(visit);
    }

    viewport.visitChildren(visit);
    for (var item = list?.firstChild;
        item != null;
        item = list!.childAfter(item)) {
      if (!item.hasSize || item.size.height <= 0) continue;
      final top = _topOf(item, viewport);
      if (top + item.size.height > 0) {
        anchor = (item: item, share: top < 0 ? -top / item.size.height : 0.0);
        return;
      }
    }
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    // A drag or an animated scroll of the list lets go.
    if (newActivity is DragScrollActivity ||
        newActivity is DrivenScrollActivity) {
      anchor = null;
    }
    super.beginActivity(newActivity);
  }

  /// Called by the list after each layout: puts the held item back where it
  /// was and asks for one more layout (false) when it had moved.
  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final applied =
        super.applyContentDimensions(minScrollExtent, maxScrollExtent);
    final held = anchor;
    if (held == null || !held.item.attached) return applied;
    final viewport = RenderAbstractViewport.maybeOf(held.item);
    final list = held.item.parent;
    if (viewport is! RenderViewportBase ||
        list is! RenderSliverMultiBoxAdaptor) {
      return applied;
    }
    // The item's height as the step to the next item: the list may not read
    // an item's size while it is laid out.
    final next = list.childAfter(held.item);
    if (next == null) return applied;
    final top = _topOf(held.item, viewport);
    final height = _topOf(next, viewport) - top;
    final target = (pixels + top + held.share * height)
        .clamp(minScrollExtent, maxScrollExtent);
    if ((target - pixels).abs() < 0.01) return applied;
    correctBy(target - pixels);
    return false;
  }
}
