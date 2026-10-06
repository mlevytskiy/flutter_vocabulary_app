/// The learn plan: eleven exercises in three stages, in plan order.
/// Source of truth is vocab-photo-api/src/learn/exercises.json; the test in
/// test/learn_exercises_test.dart keeps this copy identical (ADR-0003).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.stage,
    required this.available,
  });

  final String id;
  final String name;
  final int stage;
  final bool available;
}

const exercises = <Exercise>[
  Exercise(id: 'mnemonic-story', name: 'Mnemonic story', stage: 1, available: true),
  Exercise(id: 'match-synonyms', name: 'Match synonyms', stage: 1, available: false),
  Exercise(id: 'match-antonyms', name: 'Match antonyms', stage: 1, available: false),
  Exercise(id: 'match-definitions', name: 'Match word and definition', stage: 1, available: false),
  Exercise(id: 'pick-the-answer', name: 'Pick the right answer', stage: 2, available: false),
  Exercise(id: 'fill-the-gaps', name: 'Fill the gaps', stage: 2, available: false),
  Exercise(id: 'remember-or-not', name: 'Remember or not', stage: 2, available: false),
  Exercise(id: 'own-sentences', name: 'Make your own sentences', stage: 3, available: false),
  Exercise(id: 'translate-sentences', name: 'Translate sentences', stage: 3, available: false),
  Exercise(id: 'own-sentences-spoken', name: 'Make your own sentences (speak)', stage: 3, available: false),
  Exercise(id: 'translate-sentences-spoken', name: 'Translate sentences (speak)', stage: 3, available: false),
];
