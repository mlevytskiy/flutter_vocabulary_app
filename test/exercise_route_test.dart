import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/features/learn/coming_soon_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/exercises.dart';
import 'package:flutter_vocabulary_app/features/learn/explain_to_friend/explain_to_friend_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/learn_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/own_sentences/own_sentences_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/quiz/quiz_screen.dart';
import 'package:flutter_vocabulary_app/features/learn/translate_sentences/translate_sentences_screen.dart';
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
      for (final id in ['pick-the-answer', 'remember-or-not', 'quiz', 'match-synonyms', 'match-definitions', 'fill-the-gaps', 'sentence-patterns', 'guess-my-word', 'explain-to-friend']) {
        expect(startRouteFor(id, sessionId: 'history', groupId: 'g', group: wordGroup('g')).location,
            ExerciseRoute(sessionId: 'history', exercise: id, groupId: 'g').location);
      }
    });

    test('without a group the coming-soon screen opens', () {
      // learn-explain-to-friend: no registry row is unavailable any more, so this group-less
      // Start is the coming-soon path that stays (S-04).
      for (final id in ['explain-to-friend', 'quiz']) {
        expect(startRouteFor(id, groupId: null, group: null).location, ComingSoonRoute(exercise: id).location);
      }
    });
  });

  group('exerciseScreen (S-03, AC-04)', () {
    testWidgets('learn-explain-to-friend: every exercise opened by ExerciseRoute has its own screen; an unknown id opens the coming-soon screen, never an empty one',
        (tester) async {
      // After the last flip no registry row is unavailable: the "screen not built" example is an
      // unknown id. Mnemonic story and Dialogs from movie open their own routes, not ExerciseRoute.
      for (final e in exercises.where((e) => e.id != 'mnemonic-story' && e.id != 'dialogs-from-movie')) {
        expect(exerciseScreen(e.id, null, 'g'), isNot(isA<ComingSoonScreen>()), reason: e.id);
      }
      final screen = exerciseScreen('nope', 's', 'g');
      expect((screen as ComingSoonScreen).exerciseId, 'nope');
      await tester.pumpWidget(MaterialApp(home: screen));
      expect(find.text('Coming soon — this exercise is not ready yet.'), findsOneWidget);
    });

    test('an unknown id opens the coming-soon screen too', () {
      expect(exerciseScreen('nope', null, 'g'), isA<ComingSoonScreen>());
    });

    test('learn-translate-sentences AC-01: translate sentences opens its own screen', () {
      expect(exerciseScreen('translate-sentences', 's', 'g'), isA<TranslateSentencesScreen>());
    });

    test('learn-explain-to-friend AC-01: explain it to a friend opens its own screen', () {
      expect(exerciseScreen('explain-to-friend', 's', 'g'), isA<ExplainToFriendScreen>());
    });

    test('learn-own-sentences AC-01: own sentences opens its own screen', () {
      expect(exerciseScreen('own-sentences', 's', 'g'), isA<OwnSentencesScreen>());
    });

    test('learn-quiz AC-01: the quiz opens its own screen', () {
      expect(exerciseScreen('quiz', 's', 'g'), isA<QuizScreen>());
    });
  });
}
