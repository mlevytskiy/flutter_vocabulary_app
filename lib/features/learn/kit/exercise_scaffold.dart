import 'package:flutter/material.dart';

import 'exercise_phase.dart';
import 'result_summary.dart';

/// The lines of the frame (learn-kit S-06).
const exerciseFailedMessage = 'Could not load the exercise. Check the connection and try again.';
const exerciseDayLimitMessage = "Today's exercise limit is reached. Try again tomorrow.";
const exerciseRateLimitedMessage = 'Too many requests. Wait a moment and try again.';
const notEnoughWordsMessage = 'Not enough words for this exercise';

/// The one frame every exercise screen uses (learn-kit H-01, S-06): loading,
/// failed with Retry (Back for the day limit), not enough words with Back,
/// the round from [roundBuilder], and the summary with "Next round" / "Done".
/// Back and Done return to the learn page.
class ExerciseScaffold extends StatelessWidget {
  const ExerciseScaffold({
    super.key,
    required this.title,
    required this.phase,
    required this.onRetry,
    required this.roundBuilder,
    required this.onNextRound,
  });

  /// The exercise's name, in the top bar.
  final String title;
  final ExercisePhase phase;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, ExerciseRound round) roundBuilder;
  final VoidCallback onNextRound;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: switch (phase) {
        ExerciseLoading() => const Center(child: CircularProgressIndicator()),
        ExerciseFailed(:final reason) => _message(
            context,
            switch (reason) {
              ExerciseFailure.dayLimit => exerciseDayLimitMessage,
              ExerciseFailure.rateLimited => exerciseRateLimitedMessage,
              _ => exerciseFailedMessage,
            },
            reason == ExerciseFailure.dayLimit ? _back(context) : _button('Retry', onRetry),
          ),
        ExerciseNotEnough(:final message) => _message(context, message ?? notEnoughWordsMessage, _back(context)),
        final ExerciseRound round => roundBuilder(context, round),
        ExerciseSummary(:final outcomes, :final hasNextRound) => ResultSummary(
            outcomes: outcomes,
            hasNextRound: hasNextRound,
            onNextRound: onNextRound,
            onDone: () => Navigator.of(context).pop(),
          ),
      },
    );
  }

  Widget _button(String label, VoidCallback onPressed) =>
      ElevatedButton(onPressed: onPressed, child: Text(label));

  Widget _back(BuildContext context) => _button('Back', () => Navigator.of(context).pop());

  Widget _message(BuildContext context, String text, Widget action) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            const SizedBox(height: 24),
            action,
          ],
        ),
      );
}
