import 'package:flutter/material.dart';

/// Tags as chips with a field to add more (notes-editing, owner 2026-10-15).
/// The field suggests [suggestions] not given yet, filtered by what is typed;
/// Done adds the typed text, a tapped suggestion adds itself.
class TagEditor extends StatefulWidget {
  const TagEditor({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
    this.fieldKey,
    this.label = 'Add tag',
  });

  final List<String> tags;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  final Key? fieldKey;
  final String label;

  static Key suggestionKey(String tag) => ValueKey('tag-suggestion-$tag');

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(String text) {
    final tag = text.trim();
    _field.clear();
    if (tag.isEmpty || widget.tags.contains(tag)) return;
    widget.onChanged([...widget.tags, tag]);
  }

  Iterable<String> _options(TextEditingValue value) {
    final typed = value.text.trim().toLowerCase();
    return widget.suggestions.where((tag) =>
        !widget.tags.contains(tag) &&
        (typed.isEmpty || tag.toLowerCase().contains(typed)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in widget.tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => widget.onChanged(
                      [for (final t in widget.tags) if (t != tag) t]),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        RawAutocomplete<String>(
          textEditingController: _field,
          focusNode: _focus,
          optionsBuilder: _options,
          onSelected: _add,
          fieldViewBuilder: (context, controller, focusNode, _) => TextField(
            key: widget.fieldKey,
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (text) {
              _add(text);
              // Done keeps the field open for the next tag.
              _focus.requestFocus();
            },
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: const Icon(Icons.sell_outlined),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxHeight: 200, maxWidth: 260),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final tag in options)
                      ListTile(
                        key: TagEditor.suggestionKey(tag),
                        dense: true,
                        leading: const Icon(Icons.sell_outlined, size: 18),
                        title: Text(tag),
                        onTap: () => onSelected(tag),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
