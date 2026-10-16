import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../router/routes.dart';
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
        onDelete(item);
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

  /// Delete from the item menu. // T18: fills this (the rules of AC-20 to AC-22).
  void onDelete(CollectionItemView item) {}

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionsNotifierProvider);
    final folders =
        ref.watch(collectionFoldersProvider).valueOrNull ?? const [];
    final parentOf = {for (final f in folders) f.folderId: f.parentId};
    final notifier = ref.read(collectionsNotifierProvider.notifier);
    return Scaffold(
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
              itemWrapper: (context, item, icon) {
                // The wrapper only opens the menu on a long press without
                // moving; T17 acts on the decisions.
                return DraggableCollectionIcon(
                  item: item,
                  level: CollectionDragLevel(
                    openFolderId: state.folderId,
                    parentOf: parentOf,
                    levelIds: [for (final i in state.items ?? const []) i.id],
                  ),
                  onDecision: (_) {}, // T17
                  onLongPressNoMove: () => openItemMenu(item),
                  child: Builder(builder: (context) {
                    _anchors[item.id] = context;
                    return icon;
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
