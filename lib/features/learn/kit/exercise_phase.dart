import 'package:flutter/foundation.dart';

import '../../../core/services/learn_api_service.dart';
import 'result_summary.dart';

/// Why an exercise could not load or check (learn-kit S-06). Each has its
/// own line in the frame.
enum ExerciseFailure { network, timeout, dayLimit, rateLimited, failed }

/// The failure to show for an error thrown while loading or checking:
/// a [LearnApiException] maps one to one (no storage on the Worker shows as
/// [ExerciseFailure.failed]); anything else is [ExerciseFailure.failed].
ExerciseFailure failureOf(Object error) {
  if (error is! LearnApiException) return ExerciseFailure.failed;
  return switch (error.error) {
    LearnApiError.network => ExerciseFailure.network,
    LearnApiError.timeout => ExerciseFailure.timeout,
    LearnApiError.dayLimit => ExerciseFailure.dayLimit,
    LearnApiError.rateLimited => ExerciseFailure.rateLimited,
    LearnApiError.failed || LearnApiError.unavailable => ExerciseFailure.failed,
  };
}

/// Where an exercise screen stands (learn-kit S-06). Each exercise's
/// `@riverpod` notifier (a family on collectionId + groupId) exposes its phase
/// plus its own round data; [ExerciseScaffold] draws every phase but the
/// round body.
sealed class ExercisePhase {
  const ExercisePhase();
}

/// Data is loading before round 1 (AC-06).
class ExerciseLoading extends ExercisePhase {
  const ExerciseLoading();
}

/// The data could not be loaded: one error line, Retry or Back (AC-07, AC-27, AC-34c).
class ExerciseFailed extends ExercisePhase {
  const ExerciseFailed(this.reason);
  final ExerciseFailure reason;
}

/// Too few usable words for the smallest round (AC-08). [message] is the
/// exercise's own text, else the default line.
class ExerciseNotEnough extends ExercisePhase {
  const ExerciseNotEnough([this.message]);
  final String? message;
}

/// Round [index] (from 0) of [count] is in progress.
class ExerciseRound extends ExercisePhase {
  const ExerciseRound(this.index, this.count);
  final int index;
  final int count;
}

/// A round is over: every word of it with its result (AC-06).
class ExerciseSummary extends ExercisePhase {
  const ExerciseSummary(this.outcomes, {required this.hasNextRound, this.heading, this.againLabel, this.onAgain});
  final List<WordOutcome> outcomes;
  final bool hasNextRound;
  final String? heading;

  /// S-56: the extra summary button (an exam's "Repeat"); [onAgain] falls back
  /// to [ExerciseScaffold.onAgain]. Null shows no button.
  final String? againLabel;
  final VoidCallback? onAgain;
}
