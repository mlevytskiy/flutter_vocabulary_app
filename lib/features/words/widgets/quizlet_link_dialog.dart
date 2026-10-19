import 'package:flutter/material.dart';

import '../../../core/services/quizlet_link.dart';
import '../../../core/widgets/synced_text_field_row.dart';
import 'quizlet_link_how_to.dart';

/// What the learner reads during a Quizlet import (spec AC-06, AC-07).
abstract final class QuizletImportMessages {
  static const pasteSetLink = 'Paste a link to a Quizlet set.';

  /// Every read failure (AC-07): no connection, no load, no cards in time.
  static const readFailed =
      "The cards of this set couldn't be read. Try again.";
}

/// The Quizlet link dialog (import-from-quizlet SCR-02, sad §6 F1): a short
/// animation of how to get a set's link in Quizlet (it stops once the field
/// has text) above a field for text holding a Quizlet set link. Resolves with the set link found in
/// the text on Start, or null when closed. Text without a set link is refused
/// in the dialog and kept for fixing (AC-06).
Future<QuizletSetLink?> showQuizletLinkDialog(BuildContext context) {
  return showDialog<QuizletSetLink>(
    context: context,
    builder: (context) => const _QuizletLinkDialog(),
  );
}

class _QuizletLinkDialog extends StatefulWidget {
  const _QuizletLinkDialog();

  @override
  State<_QuizletLinkDialog> createState() => _QuizletLinkDialogState();
}

class _QuizletLinkDialogState extends State<_QuizletLinkDialog> {
  final _linkController = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  void _start() {
    final link = QuizletLink.find(_linkController.text);
    if (link == null) {
      setState(() => _error = QuizletImportMessages.pasteSetLink);
      return;
    }
    Navigator.pop(context, link);
  }

  @override
  Widget build(BuildContext context) {
    final style =
        Theme.of(context).textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    // Tight insets and paddings leave room for the field with the keyboard up.
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      title: const Text('Import from Quizlet'),
      content: SizedBox(
        width: double.maxFinite,
        // Reversed: when the keyboard leaves too little room, the field at the
        // bottom stays in sight and the animation scrolls away above it.
        child: SingleChildScrollView(
          reverse: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuizletLinkHowTo(playing: _linkController.text.isEmpty),
              const SizedBox(height: 12),
              TextField(
                key: const Key('quizlet-link'),
                controller: _linkController,
                autofocus: true,
                keyboardType: TextInputType.url,
                minLines: 1,
                maxLines: 4,
                // Styled like the Word and Translation fields: outline border,
                // a light resting label, 12/16 padding, bodyLarge.
                style: style,
                strutStyle:
                    StrutStyle.fromTextStyle(style, forceStrutHeight: true),
                decoration: InputDecoration(
                  labelText: 'Link to a Quizlet set',
                  labelStyle: emptyFieldLabelStyle(context),
                  floatingLabelStyle: const TextStyle(),
                  border: const OutlineInputBorder(
                      borderSide: BorderSide(width: 1)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  isDense: false,
                  errorText: _error,
                  errorMaxLines: 2,
                ),
                // Rebuilt on every change: the animation stops once there
                // is text, and a refusal is cleared by editing.
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _start,
          child: const Text('Start'),
        ),
      ],
    );
  }
}
