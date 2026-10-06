import 'package:flutter/material.dart';

import '../../../core/models/subtitle_import_options.dart';
import '../../../core/models/vocab_word.dart';
import '../../../core/services/quizlet_cards.dart';

String _formatDuration(Duration d) {
  final seconds = d.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(2)}s';
}

/// Shows the photo-analysis result dialog: timing info, the list of found
/// words (each removable before accepting), and a Done button. Resolves
/// with whatever words are left un-removed when the user taps Done, or
/// `null`/an empty list if none should be added -- the caller decides what
/// to do with that (see `_addWordsFromPhoto` at the word_input_screen.dart
/// call site).
Future<List<VocabWord>?> showVocabResultDialog(
  BuildContext context,
  List<VocabWord> words, {
  required Duration compressDuration,
  required Duration requestDuration,
  Duration? aiDuration,
}) {
  final timingLines = <String>[
    'Compressing photo: ${_formatDuration(compressDuration)}',
    'Sending & receiving response: ${_formatDuration(requestDuration)}',
    if (aiDuration != null) '  └ AI processing on server: ${_formatDuration(aiDuration)}',
  ];
  return _showResultDialog(
    context,
    words,
    headerText: timingLines.join('\n'),
    emptyMessage: 'No vocabulary words found in this photo.',
  );
}

/// The model · time · approximate cost line of a subtitle import (AC-21).
String subtitleInfoLine({
  required SubtitleModel model,
  required Duration elapsed,
  required int inputTokens,
  required int outputTokens,
}) {
  final cost = model.costUsd(inputTokens: inputTokens, outputTokens: outputTokens);
  final costText = cost < 0.001 ? '< \$0.001' : '≈ \$${cost.toStringAsFixed(3)}';
  return '${model.label} · ${_formatDuration(elapsed)} · $costText';
}

/// The same dialog after a subtitle import (words-from-subtitles): the
/// [infoLine] from [subtitleInfoLine] in place of the photo timing lines, and
/// its own message when no word qualified (AC-20).
Future<List<VocabWord>?> showSubtitleResultDialog(
  BuildContext context,
  List<VocabWord> words, {
  required String infoLine,
}) =>
    _showResultDialog(
      context,
      words,
      headerText: infoLine,
      emptyMessage: 'No new words above your level in these subtitles.',
    );

/// The skipped-cards line of a Quizlet import (AC-09, AC-10).
String quizletSkippedLine(int skipped) =>
    '$skipped ${skipped == 1 ? 'card' : 'cards'} skipped: already in the session, repeated or without text';

/// The same dialog after a Quizlet import: the set's [setName] on top, then
/// the "Read X of Y cards" line only when fewer cards were found than the set
/// states (AC-08), the skipped-cards line only when some were skipped, and
/// "No new words in this set." when nothing is left (AC-04b).
Future<List<VocabWord>?> showQuizletResultDialog(
  BuildContext context,
  QuizletProposal proposal, {
  required String setName,
}) =>
    _showResultDialog(
      context,
      proposal.words,
      headerText: [
        if (proposal.readLine != null) proposal.readLine!,
        if (proposal.skipped > 0) quizletSkippedLine(proposal.skipped),
      ].join('\n'),
      emptyMessage: 'No new words in this set.',
      setName: setName,
    );

Future<List<VocabWord>?> _showResultDialog(
  BuildContext context,
  List<VocabWord> words, {
  required String headerText,
  required String emptyMessage,
  String? setName,
}) {
  // Words the user hasn't crossed out; whatever is left here when the
  // dialog is closed gets added to the main screen.
  final remainingWords = List<VocabWord>.of(words);

  return showDialog<List<VocabWord>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Vocabulary Found'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (setName != null) ...[
                    Text(setName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: headerText.isEmpty ? 12 : 4),
                  ],
                  if (headerText.isNotEmpty) ...[
                    Text(
                      headerText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Flexible(
                    child: remainingWords.isEmpty
                        ? Text(emptyMessage)
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: remainingWords.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final w = remainingWords[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            w.word,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          if (w.translation != null) Text('Translation: ${w.translation}'),
                                          if (w.description != null) Text('Definition: ${w.description}'),
                                          if (w.context != null)
                                            Text(
                                              'Context: ${w.context}',
                                              style: const TextStyle(fontStyle: FontStyle.italic),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.black),
                                    tooltip: 'Skip this word',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      setDialogState(() {
                                        remainingWords.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, remainingWords),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    },
  );
}
