import 'package:flutter/material.dart';

import '../../core/models/tag_kind.dart';
import '../../core/services/collection_search_scope.dart';
import '../../core/services/tag_rules.dart';
import '../tags/tag_chip.dart';

/// One tag the filter can pick, with how many collections the draft finds
/// that carry it.
typedef FilterTagOption = ({TagKind kind, String text, int count});

/// The filter sheet's one tag field for both kinds (filter-sheet-pills, owner
/// 2026-10-18): the picked tags as chips with a delete button, then an input.
/// While typing, up to [maxSuggestions] tags matching by word start show
/// under the box, the typed part bold, each with its kind and live count; one
/// with 0 matches is disabled. Enter picks the first one. Only tags in use can
/// be picked, so there is no row for a new tag.
class FilterTagField extends StatefulWidget {
  const FilterTagField({
    super.key,
    required this.picked,
    required this.options,
    required this.onToggle,
  });

  final List<QuickTag> picked;
  final List<FilterTagOption> options;
  final void Function(TagKind kind, String text) onToggle;

  static const inputKey = Key('filter-tag-input');
  static const maxSuggestions = 6;
  static Key optionKey(TagKind kind, String text) =>
      ValueKey('filter-tag-option-${kind.name}-$text');

  @override
  State<FilterTagField> createState() => _FilterTagFieldState();
}

class _FilterTagFieldState extends State<FilterTagField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _isPicked(TagKind kind, String text) => widget.picked
      .any((p) => p.kind == kind && tagKey(p.text) == tagKey(text));

  /// Where [query] starts a word of [text], or -1.
  static int _wordStart(String text, String query) {
    final lower = text.toLowerCase();
    var i = lower.indexOf(query);
    while (i >= 0) {
      if (i == 0 ||
          !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(lower[i - 1])) {
        return i;
      }
      i = lower.indexOf(query, i + 1);
    }
    return -1;
  }

  List<(FilterTagOption, int)> _suggestions() {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final o in widget.options)
        if (!_isPicked(o.kind, o.text))
          if (_wordStart(o.text, q) case final at when at >= 0) (o, at),
    ].take(FilterTagField.maxSuggestions).toList();
  }

  void _pick(FilterTagOption o) {
    _controller.clear();
    widget.onToggle(o.kind, o.text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final suggestions = _suggestions();
    final typed = _controller.text.trim().length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focus.hasFocus ? scheme.primary : scheme.outlineVariant,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.picked.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in widget.picked)
                      TagChip(
                        key: ValueKey('filter-picked-${p.kind.name}-${p.text}'),
                        kind: p.kind,
                        text: p.text,
                        onDeleted: () => widget.onToggle(p.kind, p.text),
                      ),
                  ],
                ),
              TextField(
                key: FilterTagField.inputKey,
                controller: _controller,
                focusNode: _focus,
                decoration: InputDecoration(
                  hintText:
                      widget.picked.isEmpty ? 'Filter by tag…' : 'Add a tag…',
                  border: InputBorder.none,
                  isDense: true,
                ),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  final first = _suggestions()
                      .where((s) => s.$1.count > 0)
                      .map((s) => s.$1)
                      .firstOrNull;
                  if (first != null) _pick(first);
                },
              ),
            ],
          ),
        ),
        if (suggestions.isEmpty && typed > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              'No tag starts with “${_controller.text.trim()}”',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (o, at) in suggestions)
                  ListTile(
                    key: FilterTagField.optionKey(o.kind, o.text),
                    dense: true,
                    enabled: o.count > 0,
                    onTap: () => _pick(o),
                    leading: _KindDot(kind: o.kind),
                    minLeadingWidth: 8,
                    title: Text.rich(TextSpan(children: [
                      TextSpan(text: o.text.substring(0, at)),
                      TextSpan(
                        text: o.text.substring(at, at + typed),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: o.text.substring(at + typed)),
                    ])),
                    trailing: Text(
                      '${o.kind == TagKind.origin ? 'origin' : 'topic'} · ${o.count}',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The kind's tint as a small dot, as on [TagChip].
class _KindDot extends StatelessWidget {
  const _KindDot({required this.kind});

  final TagKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kind == TagKind.origin ? scheme.secondary : scheme.tertiary,
      ),
    );
  }
}
