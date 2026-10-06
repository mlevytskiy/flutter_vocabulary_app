import 'package:flutter/material.dart';

import '../../core/models/vocab_word.dart';
import '../../core/services/quizlet_cards.dart';
import '../../core/services/quizlet_set_parser.dart';
import 'quizlet_read_controller.dart';
import 'widgets/quizlet_link_dialog.dart';
import 'widgets/quizlet_progress_dialog.dart';
import 'widgets/vocab_result_dialog.dart';

/// The set the kept words came from: its id, its name as the page states it
/// and its plain link (without a language part or sharing extras).
typedef QuizletImportedSet = ({String id, String name, String url});

/// One Quizlet import, from the link dialog to Done (import-from-quizlet
/// sad §6 F1, F2, F3): the link dialog, then the progress dialog that reads
/// the set and turns its cards into proposed words — each card's back side in
/// the field it fits, translation or definition, nothing machine-translated —
/// then the results dialog. Only
/// Done with at least one kept word changes the session, through [addWords];
/// a read failure shows one message (AC-07), a cancel shows none (AC-07b). A
/// result for a session other than the one current at Start is dropped, both
/// before the results dialog and at Done (AC-16).
Future<void> runQuizletImport({
  required BuildContext context,
  required String? Function() currentSessionId,
  required List<String> Function() sessionWords,
  required void Function(List<VocabWord> words, QuizletImportedSet set)
      addWords,
  QuizletPageDriverFactory? driverFactory,
}) async {
  final link = await showQuizletLinkDialog(context);
  if (link == null || !context.mounted) return;

  final startedIn = currentSessionId();
  QuizletProposal? proposal;

  final outcome = await showQuizletProgressDialog(
    context,
    link,
    driverFactory: driverFactory,
    afterRead: (set) async {
      proposal = proposeWords(set.cards, sessionWords(), set.statedCount);
    },
  );

  final QuizletSet set;
  switch (outcome) {
    case QuizletReadCancelled():
      return;
    case QuizletReadFailed():
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(QuizletImportMessages.readFailed)));
      }
      return;
    case QuizletReadSucceeded(set: final read):
      set = read;
  }
  final proposed = proposal;
  if (proposed == null || !context.mounted) return;
  if (currentSessionId() != startedIn) {
    debugPrint('QUIZLET: the session changed during the import; words dropped');
    return;
  }

  final kept =
      await showQuizletResultDialog(context, proposed, setName: set.name);
  if (kept == null || kept.isEmpty || !context.mounted) return;
  if (currentSessionId() != startedIn) {
    debugPrint('QUIZLET: the session changed during the import; words dropped');
    return;
  }
  addWords(kept, (id: set.setId, name: set.name, url: link.plainUrl));
}
