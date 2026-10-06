import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/vocab_word.dart';
import '../../core/providers.dart';
import '../../core/services/quizlet_cards.dart';
import '../../core/services/quizlet_set_parser.dart';
import 'lightning_rules.dart';
import 'quizlet_read_controller.dart';
import 'widgets/quizlet_link_dialog.dart';
import 'widgets/quizlet_progress_dialog.dart';
import 'widgets/vocab_result_dialog.dart';

/// The set the kept words came from: its id, its name as the page states it
/// and its plain link (without a language part or sharing extras).
typedef QuizletImportedSet = ({String id, String name, String url});

/// How many terms are translated at the same time.
const int quizletTranslateConcurrency = 6;

/// One Quizlet import, from the link dialog to Done (import-from-quizlet
/// sad §6 F1, F2, F3): the link dialog, then the progress dialog that reads
/// the set and — still open, Cancel still working — turns its cards into
/// proposed words and translates their terms, then the results dialog. Only
/// Done with at least one kept word changes the session, through [addWords];
/// a read failure shows one message (AC-07), a cancel shows none (AC-07b). A
/// result for a session other than the one current at Start is dropped, both
/// before the results dialog and at Done (AC-16).
Future<void> runQuizletImport({
  required BuildContext context,
  required WidgetRef ref,
  required String? Function() currentSessionId,
  required List<String> Function() sessionWords,
  required void Function(List<VocabWord> words, QuizletImportedSet set)
      addWords,
  QuizletPageDriverFactory? driverFactory,
}) async {
  final link = await showQuizletLinkDialog(context);
  if (link == null || !context.mounted) return;

  final startedIn = currentSessionId();
  final translator = ref.read(googleTranslateServiceProvider);
  var cancelled = false;
  QuizletProposal? proposal;

  final outcome = await showQuizletProgressDialog(
    context,
    link,
    driverFactory: driverFactory,
    afterRead: (set) async {
      final proposed = proposeWords(set.cards, sessionWords(), set.statedCount);
      final translations = await _translateTerms(
        [for (final w in proposed.words) w.word],
        (term) async =>
            (await translator.translateWord(term, from: 'en', to: 'uk')).best,
        stopped: () => cancelled,
      );
      proposal = QuizletProposal(
        words: [
          for (final (i, w) in proposed.words.indexed)
            VocabWord(
              word: w.word,
              translation: translations[i],
              description: w.description,
            ),
        ],
        skipped: proposed.skipped,
        found: proposed.found,
        stated: proposed.stated,
      );
    },
  );

  final QuizletSet set;
  switch (outcome) {
    case QuizletReadCancelled():
      cancelled = true;
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

/// Translates [terms] at most [quizletTranslateConcurrency] at a time, in
/// order of starting. A term that fails or comes back unchanged is left
/// empty, so its lightning shows like a typed word's. Once [stopped] is true
/// no further term is started.
Future<List<String>> _translateTerms(
  List<String> terms,
  Future<String> Function(String term) translate, {
  required bool Function() stopped,
}) async {
  final out = List<String>.filled(terms.length, '');
  var next = 0;
  Future<void> worker() async {
    while (!stopped() && next < terms.length) {
      final i = next++;
      try {
        final t = await translate(terms[i]);
        if (isRealTranslation(terms[i], t)) out[i] = t;
      } catch (e) {
        debugPrint('QUIZLET: a term was not translated: $e');
      }
    }
  }

  await Future.wait([
    for (var k = 0;
        k < math.min(quizletTranslateConcurrency, terms.length);
        k++)
      worker(),
  ]);
  return out;
}
