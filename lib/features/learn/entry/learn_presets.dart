/// Learn presets and the enabled-exercise rules (learn-redesign T6, ADR-0006,
/// AC-05, AC-17, AC-18). Pure Dart: no Flutter, no storage.
import '../exercises.dart';

/// The ready-made exercise mixes of the Learn entry; [custom] is any other set.
enum LearnPreset {
  quick('Quick', 'about 5 min, one-word answers only'),
  balanced('Balanced', 'about 10 min'),
  deep('Deep', 'about 20 min, all exercises'),
  custom('Custom', 'your own mix');

  const LearnPreset(this.displayName, this.subtitle);

  final String displayName;
  final String subtitle;
}

/// How many words one session takes; [all] has no limit (`count == null`).
enum WordsPerSession {
  ten(10),
  twenty(20),
  thirty(30),
  all(null);

  const WordsPerSession(this.count);

  final int? count;
}

/// The exercises that run as session pages: all but the two that open their
/// own screens.
final pageExerciseIds = <String>[
  for (final e in exercises)
    if (e.id != 'mnemonic-story' && e.id != 'dialogs-from-movie') e.id,
];

const _quick = {
  'match-synonyms',
  'match-definitions',
  'pick-the-answer',
  'remember-or-not',
  'fill-the-gaps',
  'quiz',
};

const _balanced = {
  'match-synonyms',
  'match-definitions',
  'guess-my-word',
  'pick-the-answer',
  'fill-the-gaps',
  'remember-or-not',
  'sentence-patterns',
  'quiz',
  'translate-sentences',
  'own-sentences',
};

/// The exercises a preset turns on. [LearnPreset.custom] has no set of its
/// own; it returns the balanced one as the starting point.
Set<String> presetExercises(LearnPreset preset) => switch (preset) {
      LearnPreset.quick => {..._quick},
      LearnPreset.balanced || LearnPreset.custom => {..._balanced},
      LearnPreset.deep => {...pageExerciseIds},
    };

/// The preset whose set equals [enabled], else [LearnPreset.custom].
LearnPreset presetFor(Set<String> enabled) {
  for (final p in [LearnPreset.quick, LearnPreset.balanced, LearnPreset.deep]) {
    final set = presetExercises(p);
    if (set.length == enabled.length && set.containsAll(enabled)) return p;
  }
  return LearnPreset.custom;
}

int _stageOf(String id) => exercises.firstWhere((e) => e.id == id).stage;

/// False when [id] is the last enabled page exercise of its step: a step may
/// not be left empty.
bool canTurnOff(Set<String> enabled, String id) {
  if (!enabled.contains(id)) return true;
  final stage = _stageOf(id);
  return enabled.any((o) =>
      o != id && pageExerciseIds.contains(o) && _stageOf(o) == stage);
}
