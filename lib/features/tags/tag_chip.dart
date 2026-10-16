import 'package:flutter/material.dart';

import '../../core/models/tag_kind.dart';

/// One look for a tag everywhere (collection-tags, screens.md Chip look): a
/// compact stadium chip. An origin tag has [Icons.explore_outlined] on the
/// secondary container tint, a topic tag has [Icons.tag] on the tertiary one.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.kind,
    required this.text,
    this.onDeleted,
    this.onTap,
    this.onLongPress,
  });

  final TagKind kind;
  final String text;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final origin = kind == TagKind.origin;
    final background =
        origin ? scheme.secondaryContainer : scheme.tertiaryContainer;
    final foreground =
        origin ? scheme.onSecondaryContainer : scheme.onTertiaryContainer;
    final chip = InputChip(
      avatar: Icon(origin ? Icons.explore_outlined : Icons.tag,
          size: 16, color: foreground),
      label: Text(text, style: TextStyle(color: foreground)),
      backgroundColor: background,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      deleteIconColor: foreground,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: onTap,
      onDeleted: onDeleted,
    );
    if (onLongPress == null) return chip;
    return GestureDetector(onLongPress: onLongPress, child: chip);
  }
}
