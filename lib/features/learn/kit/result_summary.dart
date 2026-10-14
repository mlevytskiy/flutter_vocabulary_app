import 'package:flutter/material.dart';

/// One word's result in a round summary: the word and what the exercise says
/// about it ("Right", "Missed 2", "Known", "Repeat"...).
class WordOutcome {
  const WordOutcome({required this.rowId, required this.word, required this.result, this.detail});

  final String rowId;
  final String word;
  final String result;

  /// S-56: a second line under the word (an exam's "Answer: … · Yours: …");
  /// null shows none.
  final String? detail;
}

/// The heading of an exam's summary (learn-quiz S-55): "N of n known", n =
/// the words in the summary.
String examHeading(int known, int total) => '$known of $total known';

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
    this.againLabel,
    this.onAgain,
  });

  final List<WordOutcome> outcomes;
  final bool hasNextRound;
  final VoidCallback onNextRound;
  final VoidCallback onDone;

  /// S-33: an exercise's own counts line, shown above the list; null shows nothing.
  final String? heading;

  /// S-56: an extra button above "Next round" / "Done" (an exam's "Repeat"),
  /// shown only when both are non-null.
  final String? againLabel;
  final VoidCallback? onAgain;

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
                  subtitle: o.detail == null ? null : Text(o.detail!),
                  trailing: Text(o.result),
                ),
            ],
          ),
        ),
        if (againLabel != null && onAgain != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ElevatedButton(onPressed: onAgain, child: Text(againLabel!)),
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
