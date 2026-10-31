import 'dart:math';

import '../../../core/services/learner_profile_store.dart';

/// The parts of the warm-up dialog (learn-warm-up-v2, ADR-0002).
enum WarmUpStep { intro, main, grammar, topic, hardEasy }

/// The three main questions, one asked per warm-up (AC-03).
enum MainQuestion { mood, goal, daily }

/// What the Learn flow walks: the steps of this warm-up (3 or 4), the main
/// question, and the round to keep in the store. Pure data.
class WarmUpPlan {
  const WarmUpPlan({required this.steps, required this.main, required this.round});

  final List<WarmUpStep> steps;
  final MainQuestion main;

  /// The questions still to ask in this round, [main] first. Save it with
  /// `LearnerProfileStore.setRound`; `markMainAnswered(main.name)` drops [main]
  /// once it was answered.
  final List<String> round;
}

/// Builds the warm-up from the stored profile (AC-01, AC-02, AC-03, AC-06,
/// AC-07, AC-08). The intro comes only without a level; the grammar question
/// only with a level, when 4 or more warm-ups finished since the last one, and
/// not when the daily talk limit is reached; never both in one warm-up.
WarmUpPlan planWarmUp({
  required LearnerProfile profile,
  required bool talkLimitReached,
  required Random random,
}) {
  final known = MainQuestion.values.map((q) => q.name).toSet();
  var round = profile.round.where(known.contains).toList();
  if (round.isEmpty || round.length != profile.round.length) {
    round = known.toList()..shuffle(random);
  }
  final main = MainQuestion.values.firstWhere((q) => q.name == round.first);

  final intro = profile.level == null;
  final grammar = !intro && profile.grammarCounter >= 4 && !talkLimitReached;
  return WarmUpPlan(
    steps: [
      if (intro) WarmUpStep.intro,
      WarmUpStep.main,
      if (grammar) WarmUpStep.grammar,
      WarmUpStep.topic,
      WarmUpStep.hardEasy,
    ],
    main: main,
    round: round,
  );
}
