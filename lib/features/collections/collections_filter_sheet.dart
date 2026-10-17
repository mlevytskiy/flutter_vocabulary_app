import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/tag_kind.dart';
import '../../core/providers.dart';
import '../../core/services/collection_search.dart';
import '../../core/services/tag_rules.dart';
import 'collections_results_view.dart';

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
/// AC-38). Returns the draft on "Show N collections" (N = 0 still applies)
/// and null when dismissed, which changes nothing. The search text of
/// [current] is kept.
Future<CollectionFilter?> showCollectionsFilterSheet(
  BuildContext context, {
  required CollectionFilter current,
  DateRangePicker? pickRange,
}) {
  return showModalBottomSheet<CollectionFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: CollectionsFilterSheet(
        current: current,
        pickRange: pickRange ?? _defaultPicker,
      ),
    ),
  );
}

class CollectionsFilterSheet extends ConsumerStatefulWidget {
  const CollectionsFilterSheet({
    super.key,
    required this.current,
    this.pickRange = _defaultPicker,
  });

  final CollectionFilter current;
  final DateRangePicker pickRange;

  @override
  ConsumerState<CollectionsFilterSheet> createState() =>
      _CollectionsFilterSheetState();
}

class _CollectionsFilterSheetState
    extends ConsumerState<CollectionsFilterSheet> {
  static const _shownFirst = 12;

  late CollectionFilter _draft = widget.current;
  final _narrow = {
    TagKind.origin: TextEditingController(),
    TagKind.topic: TextEditingController(),
  };
  final _showAll = {TagKind.origin: false, TagKind.topic: false};

  @override
  void dispose() {
    for (final c in _narrow.values) {
      c.dispose();
    }
    super.dispose();
  }

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

  void _reset() {
    for (final c in _narrow.values) {
      c.clear();
    }
    setState(() => _draft = CollectionFilter(query: _draft.query));
  }

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

  Future<void> _custom(bool created) async {
    final now = created ? _draft.created : _draft.edited;
    final range = await widget.pickRange(
      context,
      now.isCustom ? DateTimeRange(start: now.start!, end: now.end!) : null,
    );
    if (range == null || !mounted) return;
    final problem = rangeProblem(range.start, range.end);
    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final choice = DateChoice.custom(range.start, range.end);
    setState(() =>
        _draft = created ? _copy(created: choice) : _copy(edited: choice));
  }

  Widget _tagSection(
    String title,
    TagKind kind,
    List<CollectionSummary> summaries,
  ) {
    final counts = tagCounts(summaries, kind);
    final picked =
        kind == TagKind.origin ? _draft.originTags : _draft.topicTags;
    final pickedKeys = {for (final t in picked) tagKey(t)};
    final narrow = _narrow[kind]!.text.trim().toLowerCase();
    final matching = [
      for (final c in counts)
        if (narrow.isEmpty || c.text.toLowerCase().contains(narrow)) c,
    ];
    final all = _showAll[kind]!;
    final shown = all ? matching : matching.take(_shownFirst).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (counts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No tags yet'),
          )
        else ...[
          TextField(
            key: Key('narrow-${kind.name}'),
            controller: _narrow[kind],
            decoration: const InputDecoration(
              hintText: 'narrow…',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final c in shown)
                FilterChip(
                  key: Key('tag-${kind.name}-${c.text}'),
                  label: Text('${c.text} ${c.count}'),
                  selected: pickedKeys.contains(tagKey(c.text)),
                  onSelected: (_) => _toggleTag(kind, c.text),
                ),
            ],
          ),
          if (matching.length > _shownFirst)
            TextButton(
              onPressed: () => setState(() => _showAll[kind] = !all),
              child: Text(all ? 'Show fewer' : 'Show all'),
            ),
        ],
      ],
    );
  }

  Widget _dateRow(String title, bool created) {
    final value = created ? _draft.created : _draft.edited;
    void set(DateChoice c) =>
        setState(() => _draft = created ? _copy(created: c) : _copy(edited: c));
    Widget chip(String label, DateChoice c) => ChoiceChip(
          label: Text(label),
          selected: value == c,
          onSelected: (_) => set(c),
        );
    return _row(title, [
      chip('Any time', DateChoice.any),
      chip('Last 7 days', DateChoice.last7Days),
      chip('Last 30 days', DateChoice.last30Days),
      chip('This year', DateChoice.thisYear),
      ChoiceChip(
        label: Text(value.isCustom ? dateChoiceLabel(value) : 'Custom range…'),
        selected: value.isCustom,
        onSelected: (_) => _custom(created),
      ),
    ]);
  }

  Widget _row(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Wrap(spacing: 6, children: chips),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final summaries =
        ref.watch(collectionSummariesProvider).valueOrNull ?? const [];
    final n = searchCollections(summaries, _draft, now: DateTime.now()).length;
    const sorts = {
      CollectionSort.myOrder: 'My order',
      CollectionSort.nameAZ: 'Name A–Z',
      CollectionSort.recentlyEdited: 'Recently edited',
      CollectionSort.recentlyCreated: 'Recently created',
    };
    // Its own Scaffold so a SnackBar shows above the sheet.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Filter', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tagSection(
                          'Where it comes from', TagKind.origin, summaries),
                      _tagSection("What it's about", TagKind.topic, summaries),
                      _dateRow('Created', true),
                      _dateRow('Edited', false),
                      _row('Sort', [
                        for (final e in sorts.entries)
                          ChoiceChip(
                            label: Text(e.value),
                            selected: _draft.sort == e.key,
                            onSelected: (_) =>
                                setState(() => _draft = _copy(sort: e.key)),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: Text('Show $n collections'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
