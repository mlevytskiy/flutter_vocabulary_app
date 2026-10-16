import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/collection_level.dart';
import '../../router/routes.dart';
import '../word_input/word_input_notifier.dart';
import 'bin_dialogs.dart';
import 'collection_drag.dart';
import 'collection_icon.dart';
import 'collections_notifier.dart';
import 'collections_speed_dial.dart';
import 'collections_view.dart';
import 'fly_to_bin.dart';
import 'name_dialog.dart';

/// The Collections screen (SCR-04): the path bar (inside a folder) and the
/// icon grid of one level, with three round buttons along the bottom:
/// Settings, the recycle bin (also where a dragged icon is dropped to delete
/// it) and the plus button with New folder and New collection. A tap on the
/// recycle bin offers to open it or to switch delete mode, where each icon
/// gets a small bin button that flies it into the recycle bin.
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

enum _BinAction { open, toggleDeleteMode }

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  /// Delete mode: every icon but the current collection has a small bin
  /// button. A screen-only switch; it is off whenever the screen opens.
  bool _deleteMode = false;

  /// Items whose picture is flying to the recycle bin; drawn invisible.
  final _flying = <String>{};

  /// The recycle-bin button, where flights land; [_binBounce] while it
  /// swallows one.
  final _binKey = GlobalKey();
  bool _binBounce = false;

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

  /// Delete by a drop on the recycle bin (AC-14, AC-20 to AC-22): the
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

  /// The recycle-bin button: open the bin, or switch delete mode.
  Future<void> _binMenu() async {
    final action = await showDialog<_BinAction>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Recycle bin'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _BinAction.open),
            child: const ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text(goToBinText),
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, _BinAction.toggleDeleteMode),
            child: ListTile(
              leading: Icon(_deleteMode
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked),
              title: Text(
                  _deleteMode ? disableDeleteModeText : enableDeleteModeText),
            ),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _BinAction.open:
        const RecycleBinRoute().push(context);
      case _BinAction.toggleDeleteMode:
        setState(() => _deleteMode = !_deleteMode);
    }
  }

  /// Delete mode's small bin button: the picture flies into the recycle-bin
  /// button, then the store bins the item, with no question (it can come
  /// back from the bin). A folder holding the current collection keeps it out
  /// and says so (AC-22).
  Future<void> _binByButton(CollectionItemView item, Rect picture) async {
    final bin = _binKey.currentContext?.findRenderObject() as RenderBox?;
    if (bin == null || _flying.contains(item.id)) return;
    final landing = bin.localToGlobal(bin.size.center(Offset.zero));
    setState(() => _flying.add(item.id));
    await flyToBin(
      context,
      from: picture,
      to: landing,
      child: CollectionPicture(
        kind: item.isFolder
            ? CollectionIconKind.folder
            : CollectionIconKind.collection,
        badges: item.badges,
      ),
    );
    if (!mounted) return;
    setState(() => _binBounce = true);
    final store = await ref.read(collectionStoreProvider.future);
    final r = await store.bin(item.id);
    if (!mounted) return;
    setState(() => _flying.remove(item.id));
    if (r.result == BinResult.refusedCurrent) {
      _snack(refusedCurrentText);
    } else if (r.stayedName != null) {
      _snack(stayedText(r.stayedName!));
    }
  }

  /// A tap on a collection (AC-09, AC-18): open it with no question and go to
  /// the main screen; opening the current one changes nothing.
  Future<void> _openCollection(String id) async {
    await ref.read(wordInputNotifierProvider.notifier).open(id);
    if (mounted) const WordInputRoute().go(context);
  }

  /// New collection (AC-10): made at the end of the open folder, then shown.
  Future<void> _newCollection(String? folderId) async {
    await ref.read(wordInputNotifierProvider.notifier).newCollection(folderId);
    if (mounted) const WordInputRoute().go(context);
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
          ),
          // Settings bottom-left like the main screen's, the recycle bin in
          // the middle, the plus button bottom-right.
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton(
                  heroTag: null,
                  onPressed: () => const SettingsRoute().push(context),
                  tooltip: 'Settings',
                  elevation: 8.0,
                  shape: const CircleBorder(),
                  backgroundColor: const Color(0xff954ef3),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.settings),
                ),
                BinDropTarget(
                  level: level(),
                  onDecision: _decide,
                  // A short bounce when a flown picture lands in it.
                  builder: (context, highlighted) => AnimatedScale(
                    scale: _binBounce ? 1.18 : 1,
                    duration: const Duration(milliseconds: 120),
                    onEnd: () {
                      if (_binBounce && mounted) {
                        setState(() => _binBounce = false);
                      }
                    },
                    child: FloatingActionButton(
                      key: _binKey,
                      heroTag: null,
                      onPressed: _binMenu,
                      tooltip: 'Recycle bin',
                      elevation: 8.0,
                      shape: const CircleBorder(),
                      backgroundColor:
                          highlighted ? Colors.red[700] : binButtonColor,
                      foregroundColor: Colors.white,
                      // Filled while delete mode is on.
                      child: Icon(
                          _deleteMode ? Icons.delete : Icons.delete_outline),
                    ),
                  ),
                ),
                CollectionsSpeedDial(
                  onNewFolder: () => _newFolder(state.folderId),
                  onNewCollection: () => _newCollection(state.folderId),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              if (!state.isTopLevel)
                CollectionsPathBar(
                  parts: state.path,
                  upEnabled: true,
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
                  // Room below the last row for the round buttons.
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                  onBin: _deleteMode ? _binByButton : null,
                  hidden: _flying,
                  onTap: (item) {
                    if (item.isFolder) {
                      notifier.open(item.id);
                    } else {
                      _openCollection(item.id);
                    }
                  },
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
                          child: icon,
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
            ],
          ),
        ));
  }
}

const goToBinText = 'Go to recycle bin';
const enableDeleteModeText = 'Enable delete mode';
const disableDeleteModeText = 'Disable delete mode';
