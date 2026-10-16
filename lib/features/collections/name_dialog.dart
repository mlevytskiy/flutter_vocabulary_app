import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/collection_name.dart';

/// What the learner reads when a name cannot be saved (AC-02, SCR-02).
const nameProblemMessage = 'A name must be 1 to 60 characters on one line';

/// Which name the shared NameDialog asks for (screens SCR-02).
enum NameDialogMode {
  renameCollection('Rename collection', 'Save'),
  renameFolder('Rename folder', 'Save'),
  newFolder('New folder', 'Create');

  const NameDialogMode(this.title, this.confirmLabel);

  final String title;
  final String confirmLabel;
}

/// The shared name dialog (collections-screen SCR-02): one line, 1 to 60
/// characters (AC-02). Resolves with the name exactly as typed — no trimming,
/// the contract stores the title as typed (openapi.yaml `title`,
/// api-sync-report "No trimming") — or null on Cancel, Back or a tap outside.
Future<String?> showNameDialog(
  BuildContext context, {
  required NameDialogMode mode,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(mode: mode, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.mode, required this.initial});

  final NameDialogMode mode;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection =
        TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text;
    if (collectionNameProblem(name) != null) {
      setState(() => _error = nameProblemMessage);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mode.title),
      content: TextField(
        key: const Key('name-dialog-field'),
        controller: _controller,
        autofocus: true,
        maxLines: 1,
        // Enter adds no newline (SCR-02); other pasted line breaks reach
        // collectionNameProblem and show the error.
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp('[\r\n]'))],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(errorText: _error, errorMaxLines: 2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _save,
          child: Text(widget.mode.confirmLabel),
        ),
      ],
    );
  }
}
