import 'dart:math';

/// The grammar focus rules by level (learn-warm-up-v2 spec §8, owner proxy O1).
/// Kept in the app only; the chosen rule's name goes to the Worker with the talk.
const grammarRulesElementary = <String>[
  'Present Simple',
  'Present Continuous',
  'Past Simple',
  'Comparatives',
  'There is/are',
];

const grammarRulesIntermediate = <String>[
  'Present Perfect',
  'Past Continuous',
  'Going to / will',
  'First conditional',
  'Modal verbs for advice',
];

const grammarRulesUpper = <String>[
  'Second conditional',
  'Passive voice',
  'Reported speech',
  'Present Perfect Continuous',
  'Third conditional',
];

/// The rules a level draws from: Beginner uses the Elementary list, "Not sure"
/// the Elementary and Intermediate lists, Upper-intermediate and Advanced the
/// last list (AC-07).
List<String> grammarRulesForLevel(String level) {
  switch (level) {
    case 'Intermediate':
      return grammarRulesIntermediate;
    case 'Upper-intermediate':
    case 'Advanced':
      return grammarRulesUpper;
    case 'Not sure':
      return [...grammarRulesElementary, ...grammarRulesIntermediate];
    default:
      return grammarRulesElementary;
  }
}

/// Four rules of the level's list, picked at random (AC-07).
List<String> pickGrammarRules(String level, Random random) {
  final pool = List.of(grammarRulesForLevel(level))..shuffle(random);
  return pool.take(4).toList();
}

/// The grammar counter after a warm-up finishes: back to 0 when the grammar
/// question was answered (a rule or "No, just talk"), else up by one, so the
/// question is due on every 5th finished warm-up (AC-07).
int nextGrammarCounter({required int counter, required bool grammarAnswered}) =>
    grammarAnswered ? 0 : counter + 1;
