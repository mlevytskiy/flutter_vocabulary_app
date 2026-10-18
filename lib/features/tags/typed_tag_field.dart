import 'package:flutter/material.dart';

import '../../core/models/tag_kind.dart';
import '../../core/services/tag_rules.dart';
import 'tag_chip.dart';

/// One option of the autocomplete list: a suggestion, or (with [isNew]) the
/// typed text as a new tag.
class _Option {
  const _Option(this.text, {this.isPreset = false, this.isNew = false});

  final String text;
  final bool isPreset;
  final bool isNew;
}

/// Tags of one [TagKind] in one rounded box with two states (collection-tags,
/// ADR-0007; restyled by tag-field-restyle, owner 2026-10-17).
///
/// View state: a tinted surface with the kind's question and its tags as
/// chips; a tap anywhere opens the edit state, which [startInEditMode] shows
/// from the start (until Done or a tap outside). Edit state: an accent border, chips with a delete button, an inline
/// input and a Done check. While typing, an autocomplete list shows up to
/// [maxSuggestions] suggestions matching by word start (the typed part bold)
/// and, when the text is not one of them, an `Add "text"` row for a new tag.
/// A long press on a suggestion that is not a preset offers "Forget this
/// tag". The tag problem or limit message shows under the box.
class TypedTagField extends StatefulWidget {
  const TypedTagField({
    super.key,
    required this.kind,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
    this.onForget,
    this.knownSpellings = const [],
    this.fieldKey,
    this.startInEditMode = false,
  });

  final TagKind kind;
  final List<String> tags;
  final List<TagSuggestion> suggestions;
  final ValueChanged<List<String>> onChanged;
  final ValueChanged<String>? onForget;
  final List<String> knownSpellings;
  final Key? fieldKey;
  final bool startInEditMode;

  static Key optionKey(String tag) => ValueKey('tag-option-$tag');
  static const newOptionKey = ValueKey('tag-option-new');
  static const doneKey = ValueKey('tag-field-done');

  static String hintFor(TagKind kind) =>
      kind == TagKind.origin ? 'Where does it come from?' : 'What is it about?';

  @override
  State<TypedTagField> createState() => _TypedTagFieldState();
}

class _TypedTagFieldState extends State<TypedTagField> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  late bool _editing = widget.startInEditMode;

  /// Kept in the edit state without focus, until Done or a tap outside.
  late bool _sticky = widget.startInEditMode;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
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

  void _onFocusChange() {
    // A menu over the field (Forget this tag) takes the focus for a moment:
    // what was typed is kept as a tag only by Done, Enter or a tap outside.
    if (!mounted) return;
    setState(() {
      if (_focus.hasFocus) {
        _editing = true;
      } else if (!_sticky) {
        _editing = false;
      }
    });
  }

  void _startEditing() {
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  void _finish() {
    if (_field.text.trim().isNotEmpty && !_add(_field.text)) return;
    _sticky = false;
    _focus.unfocus();
    setState(() => _editing = false);
  }

  /// Adds [text]; false when it was refused with a message.
  bool _add(String text) {
    if (text.trim().isEmpty) {
      _field.clear();
      return true;
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
    if (result.problem != null) return false;
    _field.clear();
    if (result.tags.length != widget.tags.length) {
      widget.onChanged(result.tags);
    }
    return true;
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

  Iterable<_Option> _options(TextEditingValue value) {
    final query = value.text.trim();
    if (query.isEmpty) return const [];
    final matches = [
      for (final s in widget.suggestions)
        if (!_isAdded(s.text) && matchesWordStart(s.text, query))
          _Option(s.text, isPreset: s.isPreset),
    ].take(maxSuggestions).toList();
    final known =
        _isAdded(query) || matches.any((o) => tagKey(o.text) == tagKey(query));
    return [
      ...matches,
      if (!known && tagProblem(query) == null) _Option(query, isNew: true),
    ];
  }

  /// [text] with the part matching [query] at a word start in bold.
  TextSpan _highlight(String text, String query, TextStyle style) {
    final q = query.trim().toLowerCase();
    final lower = text.toLowerCase();
    var at = -1;
    for (var i = lower.indexOf(q);
        q.isNotEmpty && i >= 0;
        i = lower.indexOf(q, i + 1)) {
      if (i == 0 ||
          !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(lower[i - 1])) {
        at = i;
        break;
      }
    }
    if (at < 0) return TextSpan(text: text, style: style);
    final bold = style.copyWith(fontWeight: FontWeight.w700);
    return TextSpan(style: style, children: [
      TextSpan(text: text.substring(0, at)),
      TextSpan(text: text.substring(at, at + q.length), style: bold),
      TextSpan(text: text.substring(at + q.length)),
    ]);
  }

  Widget _optionRow(BuildContext context, _Option o, VoidCallback onTap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodyLarge!.copyWith(color: scheme.onSurface);
    final accent = _accent(scheme);
    final row = InkWell(
      key: o.isNew
          ? TypedTagField.newOptionKey
          : TypedTagField.optionKey(o.text),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (o.isNew) ...[
              Container(
                width: 28,
                height: 28,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(Icons.add, size: 16, color: _onAccent(scheme)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: o.isNew
                  ? Text.rich(
                      TextSpan(style: style, children: [
                        const TextSpan(text: 'Add '),
                        TextSpan(
                          text: '“${o.text}”',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text.rich(
                      _highlight(o.text, _field.text, style),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (o.isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _tint(scheme),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('New tag',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: _onTint(scheme))),
              ),
          ],
        ),
      ),
    );
    if (o.isNew || o.isPreset || widget.onForget == null) return row;
    return GestureDetector(
      onLongPressStart: (d) => _forgetMenu(d.globalPosition, o.text),
      child: row,
    );
  }

  bool get _origin => widget.kind == TagKind.origin;
  Color _tint(ColorScheme s) =>
      _origin ? s.secondaryContainer : s.tertiaryContainer;
  Color _onTint(ColorScheme s) =>
      _origin ? s.onSecondaryContainer : s.onTertiaryContainer;
  Color _accent(ColorScheme s) => _origin ? s.secondary : s.tertiary;
  Color _onAccent(ColorScheme s) => _origin ? s.onSecondary : s.onTertiary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final editing = _editing;
    final accent = _accent(scheme);
    final borderColor = _error != null
        ? scheme.error
        : editing
            ? accent
            : scheme.outlineVariant.withValues(alpha: 0);
    final inputStyle = theme.textTheme.bodyLarge;

    final input = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: editing || widget.tags.isEmpty ? 140 : 8,
      ),
      child: IntrinsicWidth(
        child: TextField(
          key: widget.fieldKey,
          controller: _field,
          focusNode: _focus,
          style: inputStyle,
          cursorColor: accent,
          textInputAction: TextInputAction.done,
          onSubmitted: (text) {
            _add(text);
            // Done keeps the field open for the next tag.
            _focus.requestFocus();
          },
          decoration: InputDecoration(
            hintText: editing
                ? 'Type a tag'
                : widget.tags.isEmpty
                    ? 'No tags yet'
                    : null,
            hintStyle: inputStyle?.copyWith(color: scheme.onSurfaceVariant),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
    );

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 10),
      decoration: BoxDecoration(
        color: editing
            ? scheme.surface
            : Color.alphaBlend(
                _tint(scheme).withValues(alpha: 0.35),
                scheme.surfaceContainerLow,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: editing
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    TypedTagField.hintFor(widget.kind),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: editing ? accent : scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: editing
                      ? IconButton(
                          key: TypedTagField.doneKey,
                          tooltip: 'Done',
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          style: IconButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: _onAccent(scheme),
                          ),
                          onPressed: _finish,
                          icon: const Icon(Icons.check),
                        )
                      : Padding(
                          key: const ValueKey('tag-field-edit-hint'),
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: scheme.onSurfaceVariant),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RawAutocomplete<_Option>(
            textEditingController: _field,
            focusNode: _focus,
            optionsBuilder: _options,
            displayStringForOption: (o) => o.text,
            onSelected: (o) => _add(o.text),
            fieldViewBuilder: (context, controller, focusNode, _) => Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in widget.tags)
                  TagChip(
                    kind: widget.kind,
                    text: tag,
                    // A chip with no action draws as disabled; in the view
                    // state a tap on it opens the edit state.
                    onTap: editing ? null : _startEditing,
                    onDeleted: editing
                        ? () => widget.onChanged([
                              for (final t in widget.tags)
                                if (t != tag) t
                            ])
                        : null,
                  ),
                input,
              ],
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  elevation: 3,
                  shadowColor: scheme.shadow.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 264),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final o in options)
                            _optionRow(context, o, () => onSelected(o)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return TextFieldTapRegion(
      onTapOutside: editing ? (_) => _finish() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _startEditing,
            child: box,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.topLeft,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 14, color: scheme.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
