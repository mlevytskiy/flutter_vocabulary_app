import 'package:flutter/widgets.dart';

import 'coming_soon_screen.dart';
import 'explain_to_friend/explain_to_friend_screen.dart';
import 'fill_the_gaps/fill_the_gaps_screen.dart';
import 'guess_my_word/guess_my_word_screen.dart';
import 'match_definitions/match_definitions_screen.dart';
import 'match_synonyms/match_synonyms_screen.dart';
import 'own_sentences/own_sentences_screen.dart';
import 'pick_the_answer/pick_the_answer_screen.dart';
import 'quiz/quiz_screen.dart';
import 'remember_or_not/remember_or_not_screen.dart';
import 'sentence_patterns/sentence_patterns_screen.dart';
import 'translate_sentences/translate_sentences_screen.dart';

/// The screen of one exercise for one word group (learn-kit S-03), built by
/// `ExerciseRoute`. A `switch` on the frozen exercise id: each exercise adds
/// one `case` here when it ships. Anything else — an unknown id, or an
/// exercise marked available whose screen is not built — opens the
/// coming-soon screen, never an empty one (AC-04).
Widget exerciseScreen(String exercise, String? collectionId, String groupId) {
  switch (exercise) {
    case 'explain-to-friend':
      return ExplainToFriendScreen(collectionId: collectionId, groupId: groupId);
    case 'fill-the-gaps':
      return FillTheGapsScreen(collectionId: collectionId, groupId: groupId);
    case 'guess-my-word':
      return GuessMyWordScreen(collectionId: collectionId, groupId: groupId);
    case 'match-definitions':
      return MatchDefinitionsScreen(collectionId: collectionId, groupId: groupId);
    case 'match-synonyms':
      return MatchSynonymsScreen(collectionId: collectionId, groupId: groupId);
    case 'own-sentences':
      return OwnSentencesScreen(collectionId: collectionId, groupId: groupId);
    case 'pick-the-answer':
      return PickTheAnswerScreen(collectionId: collectionId, groupId: groupId);
    case 'quiz':
      return QuizScreen(collectionId: collectionId, groupId: groupId);
    case 'remember-or-not':
      return RememberOrNotScreen(collectionId: collectionId, groupId: groupId);
    case 'sentence-patterns':
      return SentencePatternsScreen(collectionId: collectionId, groupId: groupId);
    case 'translate-sentences':
      return TranslateSentencesScreen(collectionId: collectionId, groupId: groupId);
    default:
      return ComingSoonScreen(exerciseId: exercise);
  }
}
