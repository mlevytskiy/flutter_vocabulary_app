import 'package:flutter/material.dart';

import '../../../core/services/quizlet_link.dart';

/// What the learner reads in the Quizlet link dialog (spec AC-06).
abstract final class QuizletImportMessages {
  static const pasteSetLink = 'Paste a link to a Quizlet set.';
}

/// The Quizlet link dialog (import-from-quizlet SCR-02, sad §6 F1): a field
/// for text holding a Quizlet set link. Resolves with the set link found in
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
    return AlertDialog(
      title: const Text('Import from Quizlet'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('quizlet-link'),
                controller: _linkController,
                autofocus: true,
                keyboardType: TextInputType.url,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Link to a Quizlet set',
                  errorText: _error,
                  errorMaxLines: 2,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
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
