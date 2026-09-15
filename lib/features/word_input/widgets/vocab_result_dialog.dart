import 'package:flutter/material.dart';

import '../../../core/models/vocab_word.dart';

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
                  Text(
                    timingLines.join('\n'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: remainingWords.isEmpty
                        ? const Text('No vocabulary words found in this photo.')
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
                                          if (w.description != null) Text('Description: ${w.description}'),
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
