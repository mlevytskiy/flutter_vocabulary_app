import 'package:flutter/material.dart';

/// One word's result in a round summary: the word and what the exercise says
/// about it ("Right", "Missed 2", "Known", "Repeat"...).
class WordOutcome {
  const WordOutcome({required this.rowId, required this.word, required this.result});

  final String rowId;
  final String word;
  final String result;
}

/// The summary after a round (learn-kit AC-06): every word of the round with
/// its result, then "Next round" while rounds remain, else "Done".
class ResultSummary extends StatelessWidget {
  const ResultSummary({
    super.key,
    required this.outcomes,
    required this.hasNextRound,
    required this.onNextRound,
    required this.onDone,
    this.heading,
  });

  final List<WordOutcome> outcomes;
  final bool hasNextRound;
  final VoidCallback onNextRound;
  final VoidCallback onDone;

  /// S-33: an exercise's own counts line, shown above the list; null shows nothing.
  final String? heading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(heading!),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final o in outcomes)
                ListTile(
                  key: ValueKey('outcome-${o.rowId}'),
                  dense: true,
                  title: Text(o.word),
                  trailing: Text(o.result),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: hasNextRound ? onNextRound : onDone,
            child: Text(hasNextRound ? 'Next round' : 'Done'),
          ),
        ),
      ],
    );
  }
}
