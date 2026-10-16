import 'package:flutter/material.dart';

/// What a [CollectionIcon] stands for on the Collections screen (SCR-04).
enum CollectionIconKind { folder, collection, recycleBin }

/// One tile of the Collections grid: a picture, the name (two lines,
/// ellipsis), "N words" and a "current" badge for a collection, and a ⋮
/// button on everything but the recycle bin. Plain values in, callbacks out.
class CollectionIcon extends StatelessWidget {
  const CollectionIcon({
    super.key,
    required this.kind,
    required this.name,
    this.wordCount = 0,
    this.isCurrent = false,
    this.onTap,
    this.onMenu,
  });

  final CollectionIconKind kind;
  final String name;
  final int wordCount;
  final bool isCurrent;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  bool get _isCollection => kind == CollectionIconKind.collection;
  bool get _hasMenu => kind != CollectionIconKind.recycleBin;

  IconData get _picture => switch (kind) {
        CollectionIconKind.folder => Icons.folder,
        CollectionIconKind.collection => Icons.style,
        CollectionIconKind.recycleBin => Icons.delete_outline,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 52,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    _picture,
                    size: 48,
                    color: kind == CollectionIconKind.folder
                        ? Colors.amber.shade600
                        : scheme.primary,
                  ),
                  if (_hasMenu)
                    Positioned(
                      right: -14,
                      top: -6,
                      child: IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Menu',
                        onPressed: onMenu,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            if (_isCollection)
              Text(
                '$wordCount words',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (_isCollection && isCurrent)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'current',
                  style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
