import 'package:flutter/material.dart';

import '../../core/models/tag_kind.dart';
import '../../core/services/tag_rules.dart';
import 'tag_chip.dart';

/// Whether the suggestion row (and helper line) is always there or only while
/// the field has focus (SCR-08, AC-34).
enum SuggestionMode { always, whenFocused }

/// Tags of one [TagKind] as chips with a field to add more (collection-tags,
/// ADR-0007; grown from the notes `TagEditor`). Shows a hint and a helper line
/// per kind, up to [maxSuggestions] suggestion chips not added yet, an
/// autocomplete list filtered by word start, the tag problem or limit message
/// under the field, and a long-press "Forget this tag" on a suggestion that
/// is not a preset. [suggestions] come in as a parameter.
class TypedTagField extends StatefulWidget {
  const TypedTagField({
    super.key,
    required this.kind,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
    this.onForget,
    this.knownSpellings = const [],
    this.mode = SuggestionMode.always,
    this.fieldKey,
  });

  final TagKind kind;
  final List<String> tags;
  final List<TagSuggestion> suggestions;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<String>? onForget;
  final List<String> knownSpellings;
  final SuggestionMode mode;
  final Key? fieldKey;

  static Key suggestionKey(String tag) => ValueKey('tag-suggestion-$tag');
  static Key optionKey(String tag) => ValueKey('tag-option-$tag');

  static String hintFor(TagKind kind) =>
      kind == TagKind.origin ? 'Where does it come from?' : 'What is it about?';

  static String helperFor(TagKind kind) => kind == TagKind.origin
      ? 'e.g. Friends (series), a podcast, a trip to London'
      : 'e.g. Food, Phrasal verbs, Job interview';

  @override
  State<TypedTagField> createState() => _TypedTagFieldState();
}

class _TypedTagFieldState extends State<TypedTagField> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _field.addListener(() {
      if (_error != null && _field.text.isNotEmpty) {
        setState(() => _error = null);
      }
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(String text) {
    if (text.trim().isEmpty) {
      _field.clear();
      return;
    }
    final result = addTag(
      widget.tags,
      text,
      knownSpellings: [
        ...widget.knownSpellings,
        for (final s in widget.suggestions) s.text,
      ],
    );
    setState(() => _error = result.problem);
    if (result.problem != null) return;
    _field.clear();
    if (result.tags.length != widget.tags.length) {
      widget.onChanged(result.tags);
    }
  }

  bool _isAdded(String text) =>
      widget.tags.any((t) => tagKey(t) == tagKey(text));

  Future<void> _forgetMenu(Offset globalPosition, String tag) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final chosen = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [PopupMenuItem(value: true, child: Text('Forget this tag'))],
    );
    if (chosen == true) widget.onForget?.call(tag);
  }

  Widget _withForget(TagSuggestion s, Widget child) {
    if (s.isPreset || widget.onForget == null) return child;
    return GestureDetector(
      onLongPressStart: (d) => _forgetMenu(d.globalPosition, s.text),
      child: child,
    );
  }

  Iterable<TagSuggestion> _options(TextEditingValue value) {
    if (value.text.trim().isEmpty) return const [];
    return widget.suggestions
        .where((s) => !_isAdded(s.text) && matchesWordStart(s.text, value.text))
        .take(maxSuggestions);
  }

  @override
  Widget build(BuildContext context) {
    final showHelp = widget.mode == SuggestionMode.always || _focus.hasFocus;
    final row = [
      for (final s in widget.suggestions)
        if (!_isAdded(s.text)) s,
    ].take(maxSuggestions).toList();
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
                TagChip(
                  kind: widget.kind,
                  text: tag,
                  onDeleted: () => widget.onChanged([
                    for (final t in widget.tags)
                      if (t != tag) t
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        RawAutocomplete<TagSuggestion>(
          textEditingController: _field,
          focusNode: _focus,
          optionsBuilder: _options,
          displayStringForOption: (s) => s.text,
          onSelected: (s) => _add(s.text),
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
              hintText: TypedTagField.hintFor(widget.kind),
              helperText:
                  showHelp ? TypedTagField.helperFor(widget.kind) : null,
              helperMaxLines: 2,
              errorText: _error,
              prefixIcon: Icon(widget.kind == TagKind.origin
                  ? Icons.explore_outlined
                  : Icons.tag),
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
                    for (final s in options)
                      _withForget(
                        s,
                        ListTile(
                          key: TypedTagField.optionKey(s.text),
                          dense: true,
                          leading: Icon(
                              widget.kind == TagKind.origin
                                  ? Icons.explore_outlined
                                  : Icons.tag,
                              size: 18),
                          title: Text(s.text),
                          onTap: () => onSelected(s),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showHelp && row.isNotEmpty) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in row)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _withForget(
                      s,
                      ActionChip(
                        key: TypedTagField.suggestionKey(s.text),
                        label: Text(s.text),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _add(s.text),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
