import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/tag_kind.dart';
import '../../core/providers.dart';
import '../../core/services/collection_search.dart';
import '../../core/services/collection_search_scope.dart';
import '../../core/services/tag_rules.dart';
import 'collections_results_view.dart';
import 'filter_tag_field.dart';

/// Picks a custom date range (SCR-07). Injectable so tests need no platform
/// picker.
typedef DateRangePicker = Future<DateTimeRange?> Function(
  BuildContext context,
  DateTimeRange? initial,
);

Future<DateTimeRange?> _defaultPicker(
  BuildContext context,
  DateTimeRange? initial,
) =>
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDateRange: initial,
    );

/// The filter sheet (collection-tags SCR-06; AC-20, AC-20b, AC-21, AC-37,
/// AC-38; Pills layout by filter-sheet-pills, owner 2026-10-18). Returns the
/// draft on "Show N collections" (N = 0 still applies) and null when
/// dismissed, which changes nothing. The search text of [current] is kept.
Future<CollectionFilter?> showCollectionsFilterSheet(
  BuildContext context, {
  required CollectionFilter current,
  DateRangePicker? pickRange,
}) {
  return showModalBottomSheet<CollectionFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CollectionsFilterSheet(
      current: current,
      pickRange: pickRange ?? _defaultPicker,
    ),
  );
}

/// The choices of the Created and Edited pills; [_DateOption.custom] opens
/// the range picker.
enum _DateOption { any, last7Days, last30Days, thisYear, custom }

const _dateOptionLabels = {
  _DateOption.any: 'Any time',
  _DateOption.last7Days: 'Last 7 days',
  _DateOption.last30Days: 'Last 30 days',
  _DateOption.thisYear: 'This year',
  _DateOption.custom: 'Custom range…',
};

const _dateOptionChoices = {
  _DateOption.any: DateChoice.any,
  _DateOption.last7Days: DateChoice.last7Days,
  _DateOption.last30Days: DateChoice.last30Days,
  _DateOption.thisYear: DateChoice.thisYear,
};

const sortLabels = {
  CollectionSort.myOrder: 'My order',
  CollectionSort.nameAZ: 'Name A–Z',
  CollectionSort.recentlyEdited: 'Recently edited',
  CollectionSort.recentlyCreated: 'Recently created',
};

class CollectionsFilterSheet extends ConsumerStatefulWidget {
  const CollectionsFilterSheet({
    super.key,
    required this.current,
    this.pickRange = _defaultPicker,
  });

  final CollectionFilter current;
  final DateRangePicker pickRange;

  static const sortKey = Key('filter-sort');
  static Key dateKey(bool created) =>
      Key(created ? 'filter-created' : 'filter-edited');
  static Key quickKey(TagKind kind, String text) =>
      ValueKey('filter-quick-${kind.name}-$text');

  @override
  ConsumerState<CollectionsFilterSheet> createState() =>
      _CollectionsFilterSheetState();
}

class _CollectionsFilterSheetState
    extends ConsumerState<CollectionsFilterSheet> {
  late CollectionFilter _draft = widget.current;

  /// Shown under the pills when a picked range is refused.
  String? _rangeError;

  CollectionFilter _copy({
    List<String>? originTags,
    List<String>? topicTags,
    DateChoice? created,
    DateChoice? edited,
    CollectionSort? sort,
  }) =>
      CollectionFilter(
        query: _draft.query,
        originTags: originTags ?? _draft.originTags,
        topicTags: topicTags ?? _draft.topicTags,
        created: created ?? _draft.created,
        edited: edited ?? _draft.edited,
        sort: sort ?? _draft.sort,
      );

  void _reset() => setState(() {
        _rangeError = null;
        _draft = CollectionFilter(query: _draft.query);
      });

  List<QuickTag> get _picked => [
        for (final t in _draft.originTags) (kind: TagKind.origin, text: t),
        for (final t in _draft.topicTags) (kind: TagKind.topic, text: t),
      ];

  bool _isPicked(TagKind kind, String text) =>
      (kind == TagKind.origin ? _draft.originTags : _draft.topicTags)
          .any((t) => tagKey(t) == tagKey(text));

  void _toggleTag(TagKind kind, String text) {
    final list = [
      ...(kind == TagKind.origin ? _draft.originTags : _draft.topicTags)
    ];
    final i = list.indexWhere((t) => tagKey(t) == tagKey(text));
    if (i >= 0) {
      list.removeAt(i);
    } else {
      list.add(text);
    }
    setState(() => _draft = kind == TagKind.origin
        ? _copy(originTags: list)
        : _copy(topicTags: list));
  }

  void _setDate(bool created, DateChoice c) => setState(() {
        _rangeError = null;
        _draft = created ? _copy(created: c) : _copy(edited: c);
      });

  Future<void> _custom(bool created) async {
    final now = created ? _draft.created : _draft.edited;
    final range = await widget.pickRange(
      context,
      now.isCustom ? DateTimeRange(start: now.start!, end: now.end!) : null,
    );
    if (range == null || !mounted) return;
    final problem = rangeProblem(range.start, range.end);
    if (problem != null) {
      setState(() => _rangeError = problem);
      return;
    }
    _setDate(created, DateChoice.custom(range.start, range.end));
  }

  /// The Popular line: up to four tags (see [quickTags]) with live counts;
  /// one that is not picked and has none is disabled (collections-search
  /// AC-09).
  Widget _quickLine(List<QuickTag> quick, List<FilterTagOption> options) {
    final scheme = Theme.of(context).colorScheme;
    int count(QuickTag q) => options
        .firstWhere((o) => o.kind == q.kind && tagKey(o.text) == tagKey(q.text),
            orElse: () => (kind: q.kind, text: q.text, count: 0))
        .count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Popular',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final q in quick) ...[
                Builder(builder: (context) {
                  final origin = q.kind == TagKind.origin;
                  final on = _isPicked(q.kind, q.text);
                  final n = count(q);
                  final fg = on
                      ? (origin ? scheme.onSecondary : scheme.onTertiary)
                      : (origin
                          ? scheme.onSecondaryContainer
                          : scheme.onTertiaryContainer);
                  return FilterChip(
                    key: CollectionsFilterSheet.quickKey(q.kind, q.text),
                    label: Text('${q.text} $n', style: TextStyle(color: fg)),
                    selected: on,
                    backgroundColor: origin
                        ? scheme.secondaryContainer
                        : scheme.tertiaryContainer,
                    selectedColor: origin ? scheme.secondary : scheme.tertiary,
                    checkmarkColor: fg,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                    onSelected: n == 0 && !on
                        ? null
                        : (_) => _toggleTag(q.kind, q.text),
                  );
                }),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _datePill(String title, bool created) {
    final value = created ? _draft.created : _draft.edited;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final active = value != DateChoice.any;
    final label = value.isCustom
        ? dateChoiceLabel(value)
        : _dateOptionLabels[_dateOptionChoices.entries
            .firstWhere((e) => e.value == value)
            .key]!;
    final selected = value.isCustom
        ? _DateOption.custom
        : _dateOptionChoices.entries.firstWhere((e) => e.value == value).key;
    return PopupMenuButton<_DateOption>(
      key: CollectionsFilterSheet.dateKey(created),
      tooltip: title,
      onSelected: (o) => o == _DateOption.custom
          ? _custom(created)
          : _setDate(created, _dateOptionChoices[o]!),
      itemBuilder: (_) => [
        for (final o in _DateOption.values)
          CheckedPopupMenuItem(
            value: o,
            checked: o == selected,
            child: Text(o == _DateOption.custom && value.isCustom
                ? dateChoiceLabel(value)
                : _dateOptionLabels[o]!),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: active ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: active ? Colors.transparent : scheme.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: active ? FontWeight.w700 : null,
                      color: active ? scheme.onPrimaryContainer : null,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _sortPill() {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<CollectionSort>(
      key: CollectionsFilterSheet.sortKey,
      tooltip: 'Sort',
      onSelected: (s) => setState(() => _draft = _copy(sort: s)),
      itemBuilder: (_) => [
        for (final e in sortLabels.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: _draft.sort == e.key,
            child: Text(e.value),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: ShapeDecoration(
          shape: StadiumBorder(side: BorderSide(color: scheme.outline)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort: ${sortLabels[_draft.sort]}',
                style: Theme.of(context).textTheme.labelLarge),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaries =
        ref.watch(collectionSummariesProvider).value ?? const [];
    final recent = ref.watch(recentFilterTagsProvider);
    final matching = searchCollections(summaries, _draft, now: DateTime.now());
    final n = matching.length;
    final options = [
      for (final kind in TagKind.values)
        for (final c in liveTagCounts(summaries, matching, kind))
          (kind: kind, text: c.text, count: c.count),
    ];
    final quick = quickTags(summaries, recent);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Filter',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                _sortPill(),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 12),
            if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No tags yet'),
              )
            else
              FilterTagField(
                picked: _picked,
                options: options,
                onToggle: _toggleTag,
              ),
            if (quick.isNotEmpty) ...[
              const SizedBox(height: 12),
              _quickLine(quick, options),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _datePill('Created', true)),
                const SizedBox(width: 8),
                Expanded(child: _datePill('Edited', false)),
              ],
            ),
            if (_rangeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _rangeError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_draft),
              child: Text('Show $n collections'),
            ),
          ],
        ),
      ),
    );
  }
}
