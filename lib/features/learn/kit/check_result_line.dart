import 'package:flutter/material.dart';

import 'check_verdict.dart';
import 'exercise_phase.dart';
import 'exercise_scaffold.dart';

/// The line under a checked sentence (learn-kit AC-28, AC-29, AC-34, S-24):
/// "Good", or the corrected sentence and a short note; or, when the check
/// could not be made, one error line with Retry (Back is the screen's own for
/// the day limit). The learner's typed text is never touched here.
class CheckResultLine extends StatelessWidget {
  const CheckResultLine.verdict(CheckVerdict this.verdict, {super.key})
      : failure = null,
        onRetry = null;

  const CheckResultLine.failed(ExerciseFailure this.failure, {super.key, required this.onRetry}) : verdict = null;

  final CheckVerdict? verdict;
  final ExerciseFailure? failure;
  final VoidCallback? onRetry;

  /// Said when the check itself failed (AC-34).
  static const checkFailedMessage = 'Could not check the sentence. Check the connection and try again.';

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    if (failure != null) {
      final text = switch (failure) {
        ExerciseFailure.dayLimit => exerciseDayLimitMessage,
        ExerciseFailure.rateLimited => exerciseRateLimitedMessage,
        _ => checkFailedMessage,
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (failure != ExerciseFailure.dayLimit)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }
    return switch (verdict!) {
      CheckRight() => const Text('Good'),
      CheckFixed(:final fixed, :final note) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fixed.isNotEmpty) Text(fixed),
            if (note.isNotEmpty) Text(note),
          ],
        ),
    };
  }
}
