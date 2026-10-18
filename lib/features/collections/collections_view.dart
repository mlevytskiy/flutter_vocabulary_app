import 'package:flutter/material.dart';

import 'collection_icon.dart';
import 'collection_pictures.dart';
import '../../core/theme/app_theme.dart';

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

/// Up, in the top bar's leading slot inside a folder (owner, 2026-10-18:
/// with the path, on the bar's one line).
class CollectionsUpButton extends StatelessWidget {
  const CollectionsUpButton({
    super.key,
    required this.enabled,
    required this.onUp,
    this.wrapper,
  });

  final bool enabled;
  final VoidCallback onUp;

  /// Wraps the button, e.g. in a drop target (T17).
  final Widget Function(BuildContext context, Widget child)? wrapper;

  @override
  Widget build(BuildContext context) {
    final up = IconButton(
      onPressed: enabled ? onUp : null,
      tooltip: 'Up',
      icon: const Icon(Icons.arrow_upward),
    );
    return wrapper?.call(context, up) ?? up;
  }
}

/// The tappable path "Collections › English course › Unit 3" as the top
/// bar's title, on one line (owner, 2026-10-18). The open folder is in the
/// bar's title style, the levels above it smaller and quieter; a path too
/// long for the bar scrolls sideways and opens at its end, so the open
/// folder always shows.
class CollectionsPathBar extends StatelessWidget {
  const CollectionsPathBar({
    super.key,
    required this.parts,
    required this.onPart,
    this.partWrapper,
  });

  final List<PathPart> parts;
  final ValueChanged<String?> onPart;

  /// Wraps each path part, e.g. in a drop target (T17).
  final Widget Function(BuildContext context, PathPart part, Widget child)?
      partWrapper;

  @override
  Widget build(BuildContext context) {
    final title = DefaultTextStyle.of(context).style;
    final above = title.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.normal,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Opens at the end: the open folder is what must show.
        reverse: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < parts.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('›', style: above),
                  ),
                _part(context, parts[i], i == parts.length - 1 ? title : above),
              ],
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _part(BuildContext context, PathPart part, TextStyle style) {
    final child = InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onPart(part.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Text(part.name, style: style, maxLines: 1, softWrap: false),
      ),
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
      return Center(
        child: Text(emptyText,
            style: TextStyle(fontSize: 18, color: AppDecor.of(context).muted)),
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
          onBin: onBin == null ? null : (rect) => onBin!(item, rect),
        );
        final shown = itemWrapper?.call(context, item, icon) ?? icon;
        return hidden.contains(item.id)
            ? Opacity(opacity: 0, child: shown)
            : shown;
      },
    );
  }
}
