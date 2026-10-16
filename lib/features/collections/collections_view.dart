import 'package:flutter/material.dart';

import 'collection_icon.dart';

/// One item of a Collections level, as the grid shows it.
@immutable
class CollectionItemView {
  const CollectionItemView({
    required this.id,
    required this.isFolder,
    required this.name,
    this.wordCount = 0,
    this.isCurrent = false,
  });

  final String id;
  final bool isFolder;
  final String name;
  final int wordCount;
  final bool isCurrent;
}

/// One part of the path: [id] is null for the top level ("Collections").
@immutable
class PathPart {
  const PathPart(this.id, this.name);

  final String? id;
  final String name;
}

/// Up plus the tappable path "Collections › English course › Unit 3".
class CollectionsPathBar extends StatelessWidget {
  const CollectionsPathBar({
    super.key,
    required this.parts,
    required this.upEnabled,
    required this.onUp,
    required this.onPart,
    this.partWrapper,
    this.upWrapper,
  });

  final List<PathPart> parts;
  final bool upEnabled;
  final VoidCallback onUp;
  final ValueChanged<String?> onPart;

  /// Wraps each path part, e.g. in a drop target (T17).
  final Widget Function(BuildContext context, PathPart part, Widget child)? partWrapper;

  /// Wraps the Up button, e.g. in a drop target (T17).
  final Widget Function(BuildContext context, Widget child)? upWrapper;

  @override
  Widget build(BuildContext context) {
    final up = TextButton.icon(
      onPressed: upEnabled ? onUp : null,
      icon: const Icon(Icons.arrow_upward),
      label: const Text('Up'),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          upWrapper?.call(context, up) ?? up,
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('›', style: TextStyle(fontSize: 16)),
                      ),
                    _part(context, parts[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _part(BuildContext context, PathPart part) {
    final child = InkWell(
      onTap: () => onPart(part.id),
      child: Text(part.name, style: const TextStyle(fontSize: 16)),
    );
    return partWrapper?.call(context, part, child) ?? child;
  }
}

/// The icons of one level in the learner's order, with the recycle bin
/// appended last when [showBin] (top level only). [items] null = loading.
class CollectionsGrid extends StatelessWidget {
  const CollectionsGrid({
    super.key,
    required this.items,
    required this.onTap,
    required this.onMenu,
    this.showBin = false,
    this.onBinTap,
    this.itemWrapper,
    this.binWrapper,
  });

  final List<CollectionItemView>? items;
  final ValueChanged<CollectionItemView> onTap;
  final ValueChanged<CollectionItemView> onMenu;
  final bool showBin;
  final VoidCallback? onBinTap;

  /// Wraps each item's icon, e.g. in a `LongPressDraggable` (T17).
  final Widget Function(BuildContext context, CollectionItemView item, Widget icon)?
      itemWrapper;

  /// Wraps the bin icon, e.g. in a drop target (T18).
  final Widget Function(BuildContext context, Widget icon)? binWrapper;

  static const emptyText = 'This folder is empty';

  @override
  Widget build(BuildContext context) {
    final list = items;
    if (list == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty && !showBin) {
      return const Center(
        child: Text(emptyText, style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }
    final count = list.length + (showBin ? 1 : 0);
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisExtent: 160,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i == list.length) {
          final bin = CollectionIcon(
            kind: CollectionIconKind.recycleBin,
            name: 'Recycle bin',
            onTap: onBinTap,
          );
          return binWrapper?.call(context, bin) ?? bin;
        }
        final item = list[i];
        final icon = CollectionIcon(
          kind: item.isFolder ? CollectionIconKind.folder : CollectionIconKind.collection,
          name: item.name,
          wordCount: item.wordCount,
          isCurrent: item.isCurrent,
          onTap: () => onTap(item),
          onMenu: () => onMenu(item),
        );
        return itemWrapper?.call(context, item, icon) ?? icon;
      },
    );
  }
}
