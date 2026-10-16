import 'package:flutter/material.dart';

import 'collection_pictures.dart';

/// What a [CollectionIcon] stands for on the Collections screen (SCR-04).
enum CollectionIconKind { folder, collection }

/// The recycle-bin button's colour; the small bin buttons of delete mode
/// match it.
const binButtonColor = Colors.blueGrey;

/// One tile of the Collections grid: the [CollectionPicture], the name (two
/// lines, ellipsis), "N words" and a "current" badge for a collection, and,
/// in delete mode ([onBin] set), a small round bin button at the top left.
/// Plain values in, taps out.
class CollectionIcon extends StatelessWidget {
  const CollectionIcon({
    super.key,
    required this.kind,
    required this.name,
    this.wordCount = 0,
    this.isCurrent = false,
    this.badges = const [],
    this.onTap,
    this.onBin,
  });

  final CollectionIconKind kind;
  final String name;
  final int wordCount;
  final bool isCurrent;

  /// The corner badges, top to bottom.
  final List<SourceBadge> badges;
  final VoidCallback? onTap;

  /// Delete mode: the small bin button was tapped; gets the picture's global
  /// rectangle, where its flight to the recycle bin starts.
  final ValueChanged<Rect>? onBin;

  static const binButtonTooltip = 'Move to recycle bin';

  bool get _isCollection => kind == CollectionIconKind.collection;

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
            Builder(builder: (pictureContext) {
              final picture = CollectionPicture(
                  kind: kind, isCurrent: isCurrent, badges: badges);
              final bin = onBin;
              if (bin == null) return picture;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  picture,
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _SmallBinButton(onTap: () {
                      final box =
                          pictureContext.findRenderObject() as RenderBox;
                      bin(box.localToGlobal(Offset.zero) & box.size);
                    }),
                  ),
                ],
              );
            }),
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
                  style:
                      TextStyle(fontSize: 11, color: scheme.onPrimaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A tile's picture, 56x56: a folder, or a collection's document with its
/// corner badges. Also what flies to the recycle bin in delete mode.
class CollectionPicture extends StatelessWidget {
  const CollectionPicture({
    super.key,
    required this.kind,
    this.isCurrent = false,
    this.badges = const [],
  });

  final CollectionIconKind kind;
  final bool isCurrent;
  final List<SourceBadge> badges;

  bool get _isCollection => kind == CollectionIconKind.collection;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 56,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (_isCollection)
            DocumentPicture(
                look: isCurrent ? DocumentLook.current : DocumentLook.plain)
          else
            const FolderPicture(),
          if (_isCollection && badges.isNotEmpty)
            // A lone badge sits on the document's corner; a stack
            // of two or three stands beside it, as in Stitch.
            Positioned(
              right: badges.length == 1 ? 6 : -4,
              top: badges.length == 1 ? 2 : -4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < badges.length; i++) ...[
                    if (i > 0) const SizedBox(height: 2),
                    SourceBadgePicture(badges[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Delete mode's small bin button: a white bin on a [binButtonColor] circle,
/// 22 across, in a 32x32 touch area inside the picture's top-left corner.
class _SmallBinButton extends StatelessWidget {
  const _SmallBinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: CollectionIcon.binButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 32,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: binButtonColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 1)),
                ],
              ),
              child: const Icon(Icons.delete_outline,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
