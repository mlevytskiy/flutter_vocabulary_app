import 'package:flutter/material.dart';

import '../../../core/models/word_group.dart';

/// The learn page's pager of word groups (mnemonic-story AC-01): one card per
/// group with its name and words. Tapping a card selects it ([onSelect]);
/// swiping only browses. Exactly one card, [selectedId], looks selected.
class GroupPager extends StatefulWidget {
  const GroupPager({
    super.key,
    required this.groups,
    required this.wordsByRowId,
    required this.selectedId,
    required this.onSelect,
  });

  final List<WordGroup> groups;

  /// The English word of each `rowId`, to list a group's words.
  final Map<String, String> wordsByRowId;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Each card is at least this tall, as every tap target in the app.
  static const cardHeight = 112.0;

  @override
  State<GroupPager> createState() => _GroupPagerState();
}

class _GroupPagerState extends State<GroupPager> {
  /// Each page is a card plus this gap; the edge of the next card shows.
  static const _cardWidth = 240.0;
  static const _gap = 16.0;

  PageController? _pages;

  /// The pager's viewport fraction depends on the screen width, so the
  /// controller is rebuilt (keeping the page) when the width changes.
  PageController _pagesFor(double width) {
    final fraction = ((_cardWidth + _gap) / width).clamp(0.1, 1.0);
    final old = _pages;
    if (old != null && old.viewportFraction == fraction) return old;
    final page = old != null && old.hasClients
        ? (old.page ?? 0).round()
        : _selectedIndex();
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    return _pages =
        PageController(initialPage: page, viewportFraction: fraction);
  }

  int _selectedIndex() {
    final i = widget.groups.indexWhere((g) => g.id == widget.selectedId);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: GroupPager.cardHeight + 16,
      child: LayoutBuilder(
        builder: (context, constraints) => PageView.builder(
          controller: _pagesFor(constraints.maxWidth),
          itemCount: widget.groups.length,
          itemBuilder: (context, i) {
            final group = widget.groups[i];
            final selected = group.id == widget.selectedId;
            final words = [
              for (final id in group.rowIds)
                if (widget.wordsByRowId[id] != null) widget.wordsByRowId[id]!,
            ].join(', ');
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Card(
                key: ValueKey('group-card-${group.id}'),
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected ? primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onSelect(group.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle,
                                  color: primary, size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            words,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
