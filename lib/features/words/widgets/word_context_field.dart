import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hidden_field_text.dart';
import '../../../core/widgets/synced_text_field_row.dart';
import 'dashed_add_button.dart';

/// The row's context under the Word and Translation fields (Words: word
/// context field, owner 2026-11-03). Three looks:
/// - a context: its text with the edit pencil right after it;
/// - none: the dashed "+add context" button (the Notes dialog's
///   [DashedAddButton]);
/// - editing: a field styled like the Word and Translation fields, with an
///   OK tick in a violet circle on its right.
///
/// Editing ends on the OK tick, submit or focus loss and hands the trimmed text to
/// [onSave]; '' clears the context and brings "+add context" back. The
/// controller, the focus node and the editing flag live here.
class WordContextField extends StatefulWidget {
  const WordContextField({
    super.key,
    required this.contextText,
    required this.onSave,
  });

  final String contextText;
  final ValueChanged<String> onSave;

  static const addKey = Key('word-context-add');
  static const editKey = Key('word-context-edit');
  static const textKey = Key('word-context-text');
  static const fieldKey = Key('word-context-field');
  static const okKey = Key('word-context-ok');

  @override
  State<WordContextField> createState() => _WordContextFieldState();
}

class _WordContextFieldState extends State<WordContextField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _editing) _finish();
  }

  void _startEditing() {
    _controller.text = widget.contextText;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _focusNode.requestFocus();
    });
  }

  void _finish() {
    if (!_editing) return;
    final text = _controller.text.trim();
    setState(() => _editing = false);
    if (text != widget.contextText.trim()) widget.onSave(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) return _field(context);
    final text = widget.contextText.trim();
    if (text.isEmpty) {
      return DashedAddButton(
        key: WordContextField.addKey,
        label: '+add context',
        color: _pencilColor(context),
        onPressed: _startEditing,
      );
    }
    // Variant B (owner, 2026-11-03): the sentence as plain text with the
    // edit pencil right after its last word.
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Text.rich(
        key: WordContextField.textKey,
        TextSpan(
          children: [
            TextSpan(text: text),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Tooltip(
                message: 'Edit context',
                child: InkWell(
                  key: WordContextField.editKey,
                  onTap: _startEditing,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: _pencilColor(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontSize: 15, height: 1.35),
      ),
    );
  }

  /// Styled exactly like the Word and Translation fields
  /// (`SyncedTextFieldRow`): outline border, 12/16 padding, bodyLarge with a
  /// forced strut.
  Widget _field(BuildContext context) {
    final style =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    return TextField(
      key: WordContextField.fieldKey,
      controller: _controller,
      focusNode: _focusNode,
      scrollPadding: rowFieldScrollPadding,
      style: HiddenFieldText.styleFor(context, _controller, style),
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      minLines: 1,
      maxLines: null,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      textAlignVertical: TextAlignVertical.top,
      onSubmitted: (_) => _finish(),
      decoration: InputDecoration(
        labelText: 'Context',
        labelStyle: emptyFieldLabelStyle(context),
        floatingLabelStyle: const TextStyle(),
        border: const OutlineInputBorder(borderSide: BorderSide(width: 1)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        isDense: false,
        // OK: saves the context, like Done on the keyboard.
        suffixIcon: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CircleIconButton(
              key: WordContextField.okKey,
              icon: Icons.check_rounded,
              tooltip: 'Save context',
              onPressed: _finish,
            ),
          ),
        ),
      ),
    );
  }
}

/// "+add context", the edit pencil and the OK tick with its circle: halfway
/// between the title's rename pencil ([AppDecor.onBarButtonOf]) and
/// [AppDecor.contextAccent] (owner, 2026-11-03).
Color _pencilColor(BuildContext context) {
  final decor = AppDecor.of(context);
  return Color.lerp(decor.onBarButtonOf(context), decor.contextAccent, 0.5)!;
}

/// A 32 px circle of [_pencilColor] at 18% opacity holding an
/// 18 px icon in that colour: the context field's OK tick.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  static const size = 32.0;

  @override
  Widget build(BuildContext context) {
    final accent = _pencilColor(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: accent.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 18, color: accent),
          ),
        ),
      ),
    );
  }
}
