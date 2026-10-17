import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/tag_kind.dart';
import '../../core/services/collection_search.dart';
import '../tags/tag_chip.dart';
import 'collection_icon.dart';

/// The flat results of the Collections search (collection-tags SCR-05): a
/// row of removable chips for the active filters with Clear, then the
/// matching collections from every folder, or "No collections match".
class CollectionsResultsView extends StatelessWidget {
  const CollectionsResultsView({
    super.key,
    required this.filter,
    required this.results,
    required this.onOpen,
    required this.onClear,
    required this.onRemoveTag,
    required this.onClearCreated,
    required this.onClearEdited,
  });

  final CollectionFilter filter;

  /// The matches in the chosen sort; null while the summaries load.
  final List<CollectionSummary>? results;
  final ValueChanged<String> onOpen;
  final VoidCallback onClear;
  final void Function(TagKind kind, String text) onRemoveTag;
  final VoidCallback onClearCreated;
  final VoidCallback onClearEdited;

  static const emptyText = 'No collections match';
  static const clearFiltersText = 'Clear filters';

  @override
  Widget build(BuildContext context) {
    final list = results;
    final chips = <Widget>[
      for (final t in filter.originTags)
        TagChip(
          kind: TagKind.origin,
          text: t,
          onDeleted: () => onRemoveTag(TagKind.origin, t),
        ),
      for (final t in filter.topicTags)
        TagChip(
          kind: TagKind.topic,
          text: t,
          onDeleted: () => onRemoveTag(TagKind.topic, t),
        ),
      if (filter.created.isActive)
        InputChip(
          label: Text('Created: ${dateChoiceLabel(filter.created)}'),
          visualDensity: VisualDensity.compact,
          onDeleted: onClearCreated,
        ),
      if (filter.edited.isActive)
        InputChip(
          label: Text('Edited: ${dateChoiceLabel(filter.edited)}'),
          visualDensity: VisualDensity.compact,
          onDeleted: onClearEdited,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in chips)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: c,
                          ),
                      ],
                    ),
                  ),
                ),
                TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
          ),
        Expanded(
          child: list == null
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emptyText,
                              style: TextStyle(
                                  fontSize: 18,
                                  color: AppDecor.of(context).muted)),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: onClear,
                            child: const Text(clearFiltersText),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      // Room below the last row for the round buttons.
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: list.length,
                      itemBuilder: (context, i) => CollectionResultTile(
                        summary: list[i],
                        onTap: () => onOpen(list[i].id),
                      ),
                    ),
        ),
      ],
    );
  }
}

/// One result: the document picture, the name, the folder path and the
/// collection's own origin and topic tags.
class CollectionResultTile extends StatelessWidget {
  const CollectionResultTile({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final CollectionSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tags = [
      for (final t in summary.originTags)
        TagChip(kind: TagKind.origin, text: t),
      for (final t in summary.topicTags) TagChip(kind: TagKind.topic, text: t),
    ];
    return ListTile(
      onTap: onTap,
      // A long press does nothing: no drag out of a flat list (AC-22).
      onLongPress: () {},
      leading: const SizedBox.square(
        dimension: 40,
        child: FittedBox(
          child: CollectionPicture(kind: CollectionIconKind.collection),
        ),
      ),
      title: Text(summary.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary.folderPath),
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 4, runSpacing: 4, children: tags),
            ),
        ],
      ),
    );
  }
}

/// The text of a time choice, as its chip shows it: "last 30 days",
/// "1 Oct – 5 Oct".
String dateChoiceLabel(DateChoice choice) {
  if (choice.isCustom) {
    String day(DateTime d) => '${d.day} ${_months[d.month - 1]}';
    return '${day(choice.start!)} – ${day(choice.end!)}';
  }
  if (choice == DateChoice.last7Days) return 'last 7 days';
  if (choice == DateChoice.last30Days) return 'last 30 days';
  if (choice == DateChoice.thisYear) return 'this year';
  return 'any time';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
