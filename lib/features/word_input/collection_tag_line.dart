import 'package:flutter/material.dart';

import '../../core/models/tag_kind.dart';
import '../tags/tag_chip.dart';

/// The collection's tags as one horizontal line of chips under the main
/// screen's title (collection-tags SCR-01): origin tags first, then topic tags.
/// It takes no room when there are no tags. A tap on a chip reports its kind
/// and text.
class CollectionTagLine extends StatelessWidget implements PreferredSizeWidget {
  const CollectionTagLine({
    super.key,
    required this.originTags,
    required this.topicTags,
    required this.onTap,
    this.height,
  });

  static const double lineHeight = 40;

  final List<String> originTags;
  final List<String> topicTags;
  final void Function(TagKind kind, String text) onTap;

  /// When set, the line is exactly this tall and does not animate itself: the
  /// screen drives the app bar's whole height (owner V8).
  final double? height;

  bool get _hasTags => originTags.isNotEmpty || topicTags.isNotEmpty;

  @override
  Size get preferredSize =>
      Size.fromHeight(height ?? (_hasTags ? lineHeight : 0));

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      for (final t in originTags)
        TagChip(
            kind: TagKind.origin,
            text: t,
            onTap: () => onTap(TagKind.origin, t)),
      for (final t in topicTags)
        TagChip(
            kind: TagKind.topic, text: t, onTap: () => onTap(TagKind.topic, t)),
    ];
    return AnimatedContainer(
      duration:
          height == null ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.easeInOut,
      height: height ?? (_hasTags ? lineHeight : 0),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}
