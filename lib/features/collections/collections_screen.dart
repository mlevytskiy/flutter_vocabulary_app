import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/collection_level.dart';
import '../../router/routes.dart';
import 'bin_dialogs.dart';
import 'bin_drop_zone.dart';
import 'collection_drag.dart';
import 'collections_notifier.dart';
import 'collections_view.dart';
import 'name_dialog.dart';

/// The Collections screen (SCR-04): the path bar and the icon grid of one
/// level. New folder / New collection and the item menu are wired by T16/T17,
/// the recycle bin by T19.
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

enum _ItemAction { rename, delete }

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  /// The icon of each item on screen, to anchor its menu (SCR-05).
  final _anchors = <String, BuildContext>{};

  /// The item being dragged and the folder the drag started in (null = top
  /// level), kept in this State because the dragged icon's own widget can go
  /// away when a hover-open changes the level (AC-14).
  CollectionItemView? _dragged;
  String? _dragFrom;
  bool _dragging = false;

  void _dragStarted(CollectionItemView item) {
    setState(() {
      _dragged = item;
      _dragFrom = ref.read(collectionsNotifierProvider).folderId;
      _dragging = true;
    });
  }

  void _dragStopped() {
    if (_dragging && mounted) setState(() => _dragging = false);
  }

  /// Carries out what a drop means (AC-14, AC-15, AC-16).
  Future<void> _decide(DropDecision decision) async {
    final item = _dragged;
    if (item == null) return;
    final store = await ref.read(collectionStoreProvider.future);
    switch (decision) {
      case MoveInto(:final folderId, :final at):
        await store.move(item.id, folderId, at: at);
      case Reorder(:final index):
        await store.reorder(item.id, index);
      case ToBin():
        await onDelete(item);
      case RefusedIntoItself():
        _snack(RefusedIntoItself.message);
      case NoOp():
        break;
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _newFolder(String? parentId) async {
    final name = await showNameDialog(context, mode: NameDialogMode.newFolder);
    if (name == null) return;
    final store = await ref.read(collectionStoreProvider.future);
    await store.createFolder(parentId: parentId, name: name);
  }

  /// The item menu (SCR-05): Rename and Delete, also for the current
  /// collection (Delete is not hidden; T18 answers the refusal).
  Future<void> openItemMenu(CollectionItemView item) async {
    final anchor = _anchors[item.id];
    final box = anchor?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    if (anchor == null || box == null || !box.attached) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final action = await showMenu<_ItemAction>(
      context: context,
      position:
          RelativeRect.fromRect(topLeft & box.size, Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(value: _ItemAction.rename, child: Text('Rename')),
        PopupMenuItem(value: _ItemAction.delete, child: Text('Delete')),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ItemAction.rename:
        await _rename(item);
      case _ItemAction.delete:
        await onDelete(item);
    }
  }

  Future<void> _rename(CollectionItemView item) async {
    final name = await showNameDialog(
      context,
      mode: item.isFolder
          ? NameDialogMode.renameFolder
          : NameDialogMode.renameCollection,
      initial: item.name,
    );
    if (name == null) return;
    final store = await ref.read(collectionStoreProvider.future);
    await store.rename(item.id, name);
  }

  /// Delete from the item menu or a bin drop (AC-14, AC-20 to AC-22): the
  /// current collection is refused; otherwise the learner confirms (SCR-07),
  /// then the store bins it.
  Future<void> onDelete(CollectionItemView item) async {
    if (item.isCurrent) {
      _snack(refusedCurrentText);
      return;
    }
    final store = await ref.read(collectionStoreProvider.future);
    final p = await store.binPreview(item.id);
    if (p == null || !mounted) return;
    final ok = await confirmBin(
      context,
      BinPreviewView(
        name: p.name,
        isFolder: p.isFolder,
        wordCount: p.wordCount,
        collections: p.collections,
        folders: p.folders,
        currentStaysName: p.currentStaysName,
      ),
    );
    if (!ok || !mounted) return;
    final r = await store.bin(item.id);
    if (r.result == BinResult.refusedCurrent) {
      _snack(refusedCurrentText);
    } else if (r.stayedName != null) {
      _snack(stayedText(r.stayedName!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionsNotifierProvider);
    final folders =
        ref.watch(collectionFoldersProvider).valueOrNull ?? const [];
    final parentOf = {for (final f in folders) f.folderId: f.parentId};
    final notifier = ref.read(collectionsNotifierProvider.notifier);
    CollectionDragLevel level() => CollectionDragLevel(
          openFolderId: state.folderId,
          parentOf: parentOf,
          levelIds: [for (final i in state.items ?? const []) i.id],
          fromFolderId: _dragFrom,
        );
    return Listener(
        onPointerUp: (_) => _dragStopped(),
        onPointerCancel: (_) => _dragStopped(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Collections'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                tooltip: 'New folder',
                onPressed: () => _newFolder(state.folderId),
              ),
              IconButton(
                icon: const Icon(Icons.library_add_outlined),
                tooltip: 'New collection',
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              CollectionsPathBar(
                parts: state.path,
                upEnabled: !state.isTopLevel,
                onUp: notifier.up,
                onPart: notifier.open,
                upWrapper: (context, up) => UpDropTarget(
                    level: level(), onDecision: _decide, child: up),
                partWrapper: (context, part, child) => PathPartDropTarget(
                  part: part,
                  level: level(),
                  onDecision: _decide,
                  onHoverOpen: notifier.open,
                  child: child,
                ),
              ),
              Expanded(
                child: CollectionsGrid(
                  items: state.items,
                  showBin: state.isTopLevel,
                  onBinTap: () => const RecycleBinRoute().push(context),
                  onTap: (item) {
                    if (item.isFolder) notifier.open(item.id);
                  },
                  onMenu: openItemMenu,
                  binWrapper: (context, bin) => BinDropTarget(
                      level: level(), onDecision: _decide, child: bin),
                  itemWrapper: (context, item, icon) {
                    final ids = [for (final i in state.items ?? const []) i.id];
                    final index = ids.indexOf(item.id);
                    // Invisible gap targets on the tile's left edge (and the last
                    // tile's right edge) reorder to that place.
                    return Stack(
                      children: [
                        DraggableCollectionIcon(
                          item: item,
                          level: level(),
                          onDecision: _decide,
                          onHoverOpen: notifier.open,
                          onDragStarted: () => _dragStarted(item),
                          onDragEnded: _dragStopped,
                          onLongPressNoMove: () => openItemMenu(item),
                          child: Builder(builder: (context) {
                            _anchors[item.id] = context;
                            return icon;
                          }),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 8,
                          child: CollectionGapTarget(
                              index: index,
                              level: level(),
                              onDecision: _decide),
                        ),
                        if (index == ids.length - 1)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 8,
                            child: CollectionGapTarget(
                                index: ids.length,
                                level: level(),
                                onDecision: _decide),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (_dragging && !state.isTopLevel)
                BinDropTarget(
                  level: level(),
                  onDecision: _decide,
                  builder: (context, highlighted) =>
                      BinDropZone(highlighted: highlighted),
                ),
            ],
          ),
        ));
  }
}
