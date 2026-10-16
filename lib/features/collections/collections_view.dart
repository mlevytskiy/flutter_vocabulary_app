import 'package:flutter/material.dart';

import 'collection_icon.dart';
import 'collection_pictures.dart';

/// One item of a Collections level, as the grid shows it.
@immutable
class CollectionItemView {
  const CollectionItemView({
    required this.id,
    required this.isFolder,
    required this.name,
    this.wordCount = 0,
    this.isCurrent = false,
    this.badges = const [],
  });

  final String id;
  final bool isFolder;
  final String name;
  final int wordCount;
  final bool isCurrent;

  /// A collection's kinds of source, as its icon's corner badges.
  final List<SourceBadge> badges;
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
  final Widget Function(BuildContext context, PathPart part, Widget child)?
      partWrapper;

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

/// The icons of one level in the learner's order. [items] null = loading.
class CollectionsGrid extends StatelessWidget {
  const CollectionsGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.itemWrapper,
    this.padding = const EdgeInsets.all(8),
    this.onBin,
    this.hidden = const {},
  });

  final List<CollectionItemView>? items;
  final ValueChanged<CollectionItemView> onTap;

  /// Wraps each item's icon, e.g. in a `LongPressDraggable` (T17).
  final Widget Function(
      BuildContext context, CollectionItemView item, Widget icon)? itemWrapper;

  /// Room around the grid, e.g. below it for the screen's round buttons.
  final EdgeInsets padding;

  /// Delete mode: every item but the current collection gets a small bin
  /// button; this gets the item and its picture's global rectangle.
  final void Function(CollectionItemView item, Rect picture)? onBin;

  /// Items drawn invisible but still taking their place, e.g. while their
  /// picture flies to the recycle bin.
  final Set<String> hidden;

  static const emptyText = 'This folder is empty';

  @override
  Widget build(BuildContext context) {
    final list = items;
    if (list == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return const Center(
        child:
            Text(emptyText, style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }
    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisExtent: 160,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i];
        final icon = CollectionIcon(
          kind: item.isFolder
              ? CollectionIconKind.folder
              : CollectionIconKind.collection,
          name: item.name,
          wordCount: item.wordCount,
          isCurrent: item.isCurrent,
          badges: item.badges,
          onTap: () => onTap(item),
          onBin: onBin == null || item.isCurrent
              ? null
              : (rect) => onBin!(item, rect),
        );
        final shown = itemWrapper?.call(context, item, icon) ?? icon;
        return hidden.contains(item.id)
            ? Opacity(opacity: 0, child: shown)
            : shown;
      },
    );
  }
}
