import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/services/filing.dart';
import 'collections_view.dart';

/// Where a dragged icon was let go on the Collections screen (SCR-04, F6).
sealed class DropTarget {
  const DropTarget();
}

/// A folder's icon.
final class FolderIconTarget extends DropTarget {
  const FolderIconTarget(this.folderId);
  final String folderId;
}

/// A collection's icon: the dragged item takes its place (AC-14).
final class CollectionIconTarget extends DropTarget {
  const CollectionIconTarget(this.collectionId);
  final String collectionId;
}

/// The gap before the [index]th icon of the open level (`levelIds.length`
/// is the gap after the last one).
final class GapTarget extends DropTarget {
  const GapTarget(this.index);
  final int index;
}

/// The Up button.
final class UpTarget extends DropTarget {
  const UpTarget();
}

/// A part of the path; [folderId] null is the top level ("Collections").
final class PathPartTarget extends DropTarget {
  const PathPartTarget(this.folderId);
  final String? folderId;
}

/// The bin icon (top level) or the `BinDropZone` (inside folders).
final class BinTarget extends DropTarget {
  const BinTarget();
}

/// An empty spot or outside the folder area.
final class EmptySpotTarget extends DropTarget {
  const EmptySpotTarget();
}

/// What a drop means; the screen carries it out through the store.
sealed class DropDecision {
  const DropDecision();
}

/// Move into [folderId] (null = top level), at the end or [at].
final class MoveInto extends DropDecision {
  const MoveInto(this.folderId, {this.at});
  final String? folderId;
  final int? at;

  @override
  bool operator ==(Object other) =>
      other is MoveInto && other.folderId == folderId && other.at == at;
  @override
  int get hashCode => Object.hash(MoveInto, folderId, at);
  @override
  String toString() => 'MoveInto($folderId, at: $at)';
}

/// Reorder within the open level: [index] is the new `order` (the `at` of
/// `placeInLevel`).
final class Reorder extends DropDecision {
  const Reorder(this.index);
  final int index;

  @override
  bool operator ==(Object other) => other is Reorder && other.index == index;
  @override
  int get hashCode => Object.hash(Reorder, index);
  @override
  String toString() => 'Reorder($index)';
}

/// Delete under the rules of Delete (AC-20 to AC-22, T18).
final class ToBin extends DropDecision {
  const ToBin();
  @override
  bool operator ==(Object other) => other is ToBin;
  @override
  int get hashCode => (ToBin).hashCode;
  @override
  String toString() => 'ToBin()';
}

/// A folder dropped onto itself or a folder inside it (AC-15).
final class RefusedIntoItself extends DropDecision {
  const RefusedIntoItself();
  static const message = 'A folder cannot go inside itself';
  @override
  bool operator ==(Object other) => other is RefusedIntoItself;
  @override
  int get hashCode => (RefusedIntoItself).hashCode;
  @override
  String toString() => 'RefusedIntoItself()';
}

/// Nothing moves, nothing opens (AC-16).
final class NoOp extends DropDecision {
  const NoOp();
  @override
  bool operator ==(Object other) => other is NoOp;
  @override
  int get hashCode => (NoOp).hashCode;
  @override
  String toString() => 'NoOp()';
}

/// Decides what dropping [dragged] on [target] does (AC-14, AC-15, AC-16).
///
/// [openFolderId] is the level on screen (null = top), [levelIds] its items
/// in order, [parentOf] every folder's parent. The item's own folder is
/// [openFolderId] when [levelIds] holds it; otherwise (the drag went on in a
/// hover-opened folder) a folder's own parent from [parentOf], else
/// [fromFolderId].
DropDecision decideDrop({
  required CollectionItemView dragged,
  required DropTarget target,
  required String? openFolderId,
  required Map<String, String?> parentOf,
  required List<String> levelIds,
  String? fromFolderId,
}) {
  final current = levelIds.indexOf(dragged.id);
  final inLevel = current >= 0;
  final String? from = inLevel
      ? openFolderId
      : dragged.isFolder && parentOf.containsKey(dragged.id)
          ? parentOf[dragged.id]
          : fromFolderId;

  DropDecision moveTo(String? folderId, {int? at}) {
    if (dragged.isFolder && !canMoveFolderInto(dragged.id, folderId, parentOf)) {
      return const RefusedIntoItself();
    }
    if (folderId == from) return const NoOp();
    return MoveInto(folderId, at: at);
  }

  DropDecision placeAt(int at) {
    if (!inLevel) return moveTo(openFolderId, at: at);
    return at == current ? const NoOp() : Reorder(at);
  }

  return switch (target) {
    FolderIconTarget(:final folderId) => moveTo(folderId),
    CollectionIconTarget(:final collectionId) => collectionId == dragged.id
        ? const NoOp()
        : levelIds.contains(collectionId)
            ? placeAt(levelIds.indexOf(collectionId))
            : const NoOp(),
    GapTarget(:final index) =>
      placeAt(inLevel && index > current ? index - 1 : index),
    UpTarget() =>
      openFolderId == null ? const NoOp() : moveTo(parentOf[openFolderId]),
    PathPartTarget(:final folderId) => moveTo(folderId),
    BinTarget() => const ToBin(),
    EmptySpotTarget() => const NoOp(),
  };
}

/// The level a drag is judged against: the inputs of [decideDrop] that the
/// screen knows. [fromFolderId] is the folder the drag started in, needed
/// once the drag goes on inside a hover-opened folder.
@immutable
class CollectionDragLevel {
  const CollectionDragLevel({
    required this.openFolderId,
    required this.parentOf,
    required this.levelIds,
    this.fromFolderId,
  });

  final String? openFolderId;
  final Map<String, String?> parentOf;
  final List<String> levelIds;
  final String? fromFolderId;

  DropDecision decide(CollectionItemView dragged, DropTarget target) => decideDrop(
        dragged: dragged,
        target: target,
        openFolderId: openFolderId,
        parentOf: parentOf,
        levelIds: levelIds,
        fromFolderId: fromFolderId,
      );
}

/// How long a dragged item is held over a folder before it opens (AC-14).
const hoverOpenDelay = Duration(seconds: 1);

/// Draws [child] with a highlight while it is a valid target under a drag.
Widget _highlight(BuildContext context, bool on, Widget child) {
  if (!on) return child;
  final scheme = Theme.of(context).colorScheme;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: scheme.primary, width: 2),
    ),
    child: child,
  );
}

bool _valid(DropDecision d) => d is MoveInto || d is Reorder || d is ToBin;

/// A `DragTarget` for one [DropTarget] kind with the shared highlight and,
/// when [hoverOpenId] is given, the 1 s hold-to-open timer.
class _DropArea extends StatefulWidget {
  const _DropArea({
    required this.target,
    required this.level,
    required this.onDecision,
    this.ownId,
    this.ownMoved,
    this.hoverOpenFolder = false,
    this.hoverOpenId,
    this.onHoverOpen,
    this.child,
    this.builder,
  });

  final DropTarget target;
  final CollectionDragLevel level;
  final ValueChanged<DropDecision> onDecision;

  /// The id of the item this area belongs to: a drop of that same item that
  /// never moved ([ownMoved] false) is a long press without moving, not a drop.
  final String? ownId;
  final bool Function()? ownMoved;
  final bool hoverOpenFolder;
  final String? hoverOpenId;
  final ValueChanged<String?>? onHoverOpen;
  final Widget? child;
  final Widget Function(BuildContext context, bool highlighted)? builder;

  @override
  State<_DropArea> createState() => _DropAreaState();
}

class _DropAreaState extends State<_DropArea> {
  Timer? _hover;

  void _cancel() {
    _hover?.cancel();
    _hover = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  bool _isStill(CollectionItemView item) =>
      item.id == widget.ownId && !(widget.ownMoved?.call() ?? false);

  @override
  Widget build(BuildContext context) {
    return DragTarget<CollectionItemView>(
      onWillAcceptWithDetails: (details) {
        _cancel();
        final open = widget.onHoverOpen;
        if (widget.hoverOpenFolder &&
            open != null &&
            details.data.id != widget.hoverOpenId &&
            widget.hoverOpenId != widget.level.openFolderId) {
          _hover = Timer(hoverOpenDelay, () {
            _hover = null;
            if (mounted) open(widget.hoverOpenId);
          });
        }
        return true;
      },
      onLeave: (_) => _cancel(),
      onAcceptWithDetails: (details) {
        _cancel();
        if (_isStill(details.data)) return;
        widget.onDecision(widget.level.decide(details.data, widget.target));
      },
      builder: (context, candidates, _) {
        final dragged = candidates.whereType<CollectionItemView>().firstOrNull;
        final on = dragged != null && _valid(widget.level.decide(dragged, widget.target));
        final b = widget.builder;
        if (b != null) return b(context, on);
        return _highlight(context, on, widget.child ?? const SizedBox.shrink());
      },
    );
  }
}

/// An item icon on the grid (`CollectionsGrid.itemWrapper`): a long press
/// that moves drags it; released without moving calls [onLongPressNoMove]
/// (the item menu, T16). It is also a drop target — a folder icon moves the
/// item in and opens after [hoverOpenDelay]; a collection icon reorders.
/// A drop where no target takes it reports [NoOp] to [onDecision].
class DraggableCollectionIcon extends StatefulWidget {
  const DraggableCollectionIcon({
    super.key,
    required this.item,
    required this.level,
    required this.onDecision,
    required this.child,
    this.onHoverOpen,
    this.onLongPressNoMove,
    this.onDragStarted,
    this.onDragEnded,
  });

  final CollectionItemView item;
  final CollectionDragLevel level;
  final ValueChanged<DropDecision> onDecision;
  final Widget child;
  final ValueChanged<String?>? onHoverOpen;
  final VoidCallback? onLongPressNoMove;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  State<DraggableCollectionIcon> createState() => _DraggableCollectionIconState();
}

class _DraggableCollectionIconState extends State<DraggableCollectionIcon> {
  Offset? _start;
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final draggable = LayoutBuilder(
      builder: (context, constraints) => LongPressDraggable<CollectionItemView>(
        data: item,
        feedback: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : 110,
            child: widget.child,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
        onDragStarted: () => widget.onDragStarted?.call(),
        onDragEnd: (d) {
          if (!_moved) {
            widget.onLongPressNoMove?.call();
          } else if (!d.wasAccepted) {
            widget.onDecision(widget.level.decide(item, const EmptySpotTarget()));
          }
          widget.onDragEnded?.call();
        },
        child: widget.child,
      ),
    );
    final tracked = Listener(
      onPointerDown: (e) {
        _start = e.position;
        _moved = false;
      },
      onPointerMove: (e) {
        final start = _start;
        if (start != null && (e.position - start).distance > kTouchSlop) _moved = true;
      },
      child: draggable,
    );
    return _DropArea(
      target: item.isFolder ? FolderIconTarget(item.id) : CollectionIconTarget(item.id),
      level: widget.level,
      onDecision: widget.onDecision,
      ownId: item.id,
      ownMoved: () => _moved,
      hoverOpenFolder: item.isFolder,
      hoverOpenId: item.id,
      onHoverOpen: widget.onHoverOpen,
      child: tracked,
    );
  }
}

/// The gap before the [index]th icon: a drop reorders to that place.
class CollectionGapTarget extends StatelessWidget {
  const CollectionGapTarget({
    super.key,
    required this.index,
    required this.level,
    required this.onDecision,
    this.child = const SizedBox(width: 8, height: 8),
  });

  final int index;
  final CollectionDragLevel level;
  final ValueChanged<DropDecision> onDecision;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _DropArea(target: GapTarget(index), level: level, onDecision: onDecision, child: child);
}

/// The Up button as a target (`CollectionsPathBar.upWrapper`).
class UpDropTarget extends StatelessWidget {
  const UpDropTarget({
    super.key,
    required this.level,
    required this.onDecision,
    required this.child,
  });

  final CollectionDragLevel level;
  final ValueChanged<DropDecision> onDecision;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _DropArea(target: const UpTarget(), level: level, onDecision: onDecision, child: child);
}

/// A path part as a target (`CollectionsPathBar.partWrapper`); held over for
/// [hoverOpenDelay] it opens that level, unless it is the open one.
class PathPartDropTarget extends StatelessWidget {
  const PathPartDropTarget({
    super.key,
    required this.part,
    required this.level,
    required this.onDecision,
    required this.child,
    this.onHoverOpen,
  });

  final PathPart part;
  final CollectionDragLevel level;
  final ValueChanged<DropDecision> onDecision;
  final Widget child;
  final ValueChanged<String?>? onHoverOpen;

  @override
  Widget build(BuildContext context) => _DropArea(
        target: PathPartTarget(part.id),
        level: level,
        onDecision: onDecision,
        hoverOpenFolder: true,
        hoverOpenId: part.id,
        onHoverOpen: onHoverOpen,
        child: child,
      );
}

/// The bin icon (`CollectionsGrid.binWrapper`) or, with [builder], the
/// `BinDropZone` drawn highlighted while a drag is over it.
class BinDropTarget extends StatelessWidget {
  const BinDropTarget({
    super.key,
    required this.level,
    required this.onDecision,
    this.child,
    this.builder,
  }) : assert(child != null || builder != null);

  final CollectionDragLevel level;
  final ValueChanged<DropDecision> onDecision;
  final Widget? child;
  final Widget Function(BuildContext context, bool highlighted)? builder;

  @override
  Widget build(BuildContext context) => _DropArea(
        target: const BinTarget(),
        level: level,
        onDecision: onDecision,
        builder: builder,
        child: child,
      );
}
