import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/tag_kind.dart';
import '../../core/services/collection_search.dart';
import '../../core/services/collection_search_scope.dart';
import '../tags/tag_chip.dart';
import 'collection_icon.dart';

/// The results of the Collections search (collection-tags SCR-05): a row of
/// removable chips for the active filters with Clear, then what matches
/// directly in the open folder — its matching folders, then collections
/// (collections-search AC-03) — or "No collections match". When nothing is
/// here but something is outside, [emptyHere] says so instead.
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
    this.folders = const [],
    this.onOpenFolder,
    this.emptyHere,
    this.bottomPadding = 96,
  });

  final CollectionFilter filter;

  /// The matches in the chosen sort; null while the summaries load.
  final List<CollectionSummary>? results;
  final ValueChanged<String> onOpen;
  final VoidCallback onClear;
  final void Function(TagKind kind, String text) onRemoveTag;
  final VoidCallback onClearCreated;
  final VoidCallback onClearEdited;

  /// Matching folders directly here, above the collections (AC-03).
  final List<SearchFolder> folders;
  final ValueChanged<String>? onOpenFolder;

  /// The two lines shown when nothing is here but the Match outside sheet
  /// has matches (AC-08); null shows [emptyText] when [results] is empty.
  final (String, String)? emptyHere;

  /// Room below the last row, for the round buttons or the sheet's peek.
  final double bottomPadding;

  static const emptyText = 'No collections match';
  static const foldersLabel = 'Folders';
  static const collectionsLabel = 'Collections';
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
              : list.isEmpty && folders.isEmpty && emptyHere != null
                  ? Align(
                      alignment: const Alignment(0, -0.5),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emptyHere!.$1,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(emptyHere!.$2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppDecor.of(context).muted)),
                          ],
                        ),
                      ),
                    )
                  : list.isEmpty && folders.isEmpty
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
                      : ListView(
                          padding: EdgeInsets.only(bottom: bottomPadding),
                          children: [
                            if (folders.isNotEmpty) ...[
                              const _SectionLabel(foldersLabel),
                              for (final f in folders)
                                FolderResultTile(
                                  folder: f,
                                  onTap: () => onOpenFolder?.call(f.id),
                                ),
                              if (list.isNotEmpty)
                                const _SectionLabel(collectionsLabel),
                            ],
                            for (final s in list)
                              CollectionResultTile(
                                summary: s,
                                showPath: false,
                                onTap: () => onOpen(s.id),
                              ),
                          ],
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
    this.showPath = true,
  });

  final CollectionSummary summary;
  final VoidCallback onTap;

  /// The folder path under the name; off where every row is in the open
  /// folder (collections-search AC-03).
  final bool showPath;

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
          if (showPath) Text(summary.folderPath),
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

/// A matching folder directly in the open folder: a tap opens it and keeps
/// the search (collections-search AC-04).
class FolderResultTile extends StatelessWidget {
  const FolderResultTile(
      {super.key, required this.folder, required this.onTap});

  final SearchFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        key: Key('folder-result-${folder.id}'),
        onTap: onTap,
        leading: const SizedBox.square(
          dimension: 40,
          child: FittedBox(
            child: CollectionPicture(kind: CollectionIconKind.folder),
          ),
        ),
        title: Text(folder.name),
        trailing: const Icon(Icons.chevron_right),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: AppDecor.of(context).muted),
        ),
      );
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
