import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/services/learn_api_service.dart';

/// The app's verdict on a checked sentence (learn-kit H-04, S-21): the app,
/// not the AI, decides whether the word is used. Mapping to word results
/// stays D-26 / D-32 (right = known, fixed = repeat in an exam).
sealed class CheckVerdict {
  const CheckVerdict();
}

/// "Good": no fix and no note are shown (AC-28, AC-32).
class CheckRight extends CheckVerdict {
  const CheckRight();
}

/// The sentence needs work: one corrected sentence ([fixed], empty for an
/// explanation) and one short note (AC-29, AC-31, AC-33).
class CheckFixed extends CheckVerdict {
  const CheckFixed({required this.fixed, required this.note});

  final String fixed;
  final String note;
}

final _endPunctuation = RegExp(r'[.!?…;:,]+$');

/// Trim, lower-case, drop end punctuation.
String _norm(String text) => text.trim().toLowerCase().replaceFirst(_endPunctuation, '').trim();

/// Decides a check: [reply] from the Worker, [sentence] as the learner sent
/// it, [word] the stored word.
CheckVerdict judgeCheck(CheckReply reply,
    {required String sentence, required String word, required LearnCheckTask task}) {
  final appUses = matchPlaces(sentence, word).isNotEmpty;
  if (task == LearnCheckTask.explain) {
    // An explanation must not hold the word in any form; grammar is not judged.
    return !appUses && reply.usesTask ? const CheckRight() : CheckFixed(fixed: '', note: reply.note);
  }
  final aiFine = reply.usesTask && (reply.ok || reply.fixed.trim().isEmpty || _norm(reply.fixed) == _norm(sentence));
  if (appUses && aiFine) return const CheckRight();
  if (aiFine) return CheckFixed(fixed: reply.fixed, note: 'Use “$word” in your sentence.');
  return CheckFixed(fixed: reply.fixed, note: reply.note);
}

/// Why a sentence is not sent (AC-30), or null when it may be: fewer than two
/// words, or over 200 characters (300 for an explanation). The Worker refuses
/// the same input.
String? sentenceProblem(String text, LearnCheckTask task) {
  final trimmed = text.trim();
  if (trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 2) return 'Write a full sentence';
  final explain = task == LearnCheckTask.explain;
  if (trimmed.length > (explain ? 300 : 200)) {
    return explain ? 'Keep it under three hundred characters' : 'Keep it under two hundred characters';
  }
  return null;
}
