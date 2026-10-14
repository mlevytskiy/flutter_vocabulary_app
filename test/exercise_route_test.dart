import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/features/learn/coming_soon_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/exercises.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

/// learn-kit S-03, S-04: one way to open an exercise for a word group
/// (AC-03, AC-04, AC-05).
void main() {
  WordGroup wordGroup(String id, {String? dialogueId}) => WordGroup()
    ..id = id
    ..name = id
    ..dialogueId = dialogueId;

  test('ExerciseRoute sits under learn at exercise and carries ids only, as query parameters', () {
    expect(const ExerciseRoute(exercise: 'quiz', groupId: 'g1').location, '/table/learn/exercise?exercise=quiz&group-id=g1');
    expect(const ExerciseRoute(sessionId: 's1', exercise: 'quiz', groupId: 'g1').location,
        '/table/learn/exercise?session-id=s1&exercise=quiz&group-id=g1');
  });

  group('startRouteFor (S-04)', () {
    test('the two built exercises keep their screens', () {
      expect(startRouteFor('mnemonic-story', sessionId: 's', groupId: 'g', group: wordGroup('g')).location,
          const StoryRoute(sessionId: 's', groupId: 'g').location);
      expect(startRouteFor('dialogs-from-movie', groupId: 'd', group: wordGroup('d', dialogueId: 'x')).location,
          const DialogueRoute(groupId: 'd').location);
      expect(startRouteFor('dialogs-from-movie', groupId: 'g', group: wordGroup('g')).location,
          const StoryRoute(groupId: 'g').location);
    });

    test('AC-03, AC-05: every other exercise opens for the selected group of the session shown', () {
      for (final id in ['pick-the-answer', 'remember-or-not', 'quiz', 'match-synonyms', 'match-definitions', 'fill-the-gaps', 'sentence-patterns', 'guess-my-word']) {
        expect(startRouteFor(id, sessionId: 'history', groupId: 'g', group: wordGroup('g')).location,
            ExerciseRoute(sessionId: 'history', exercise: id, groupId: 'g').location);
      }
    });

    test('without a group the coming-soon screen opens', () {
      expect(startRouteFor('quiz', groupId: null, group: null).location, const ComingSoonRoute(exercise: 'quiz').location);
    });
  });

  group('exerciseScreen (S-03, AC-04)', () {
    testWidgets('an exercise whose screen is not built opens the coming-soon screen, never an empty one', (tester) async {
      for (final e in exercises.where((e) => e.id != 'mnemonic-story' && e.id != 'dialogs-from-movie' && e.id != 'pick-the-answer' && e.id != 'remember-or-not' && e.id != 'match-synonyms' && e.id != 'match-definitions' && e.id != 'fill-the-gaps' && e.id != 'sentence-patterns' && e.id != 'guess-my-word')) {
        final screen = exerciseScreen(e.id, null, 'g');
        expect(screen, isA<ComingSoonScreen>(), reason: e.id);
        expect((screen as ComingSoonScreen).exerciseId, e.id);
      }
      await tester.pumpWidget(MaterialApp(home: exerciseScreen('quiz', 's', 'g')));
      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Coming soon — this exercise is not ready yet.'), findsOneWidget);
    });

    test('an unknown id opens the coming-soon screen too', () {
      expect(exerciseScreen('nope', null, 'g'), isA<ComingSoonScreen>());
    });
  });
}
