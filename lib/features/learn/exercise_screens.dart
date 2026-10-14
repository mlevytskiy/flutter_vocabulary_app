import 'package:flutter/widgets.dart';

import 'coming_soon_screen.dart';
import 'match_definitions/match_definitions_screen.dart';
import 'match_synonyms/match_synonyms_screen.dart';
import 'pick_the_answer/pick_the_answer_screen.dart';
import 'remember_or_not/remember_or_not_screen.dart';

/// The screen of one exercise for one word group (learn-kit S-03), built by
/// `ExerciseRoute`. A `switch` on the frozen exercise id: each exercise adds
/// one `case` here when it ships. Anything else — an unknown id, or an
/// exercise marked available whose screen is not built — opens the
/// coming-soon screen, never an empty one (AC-04).
Widget exerciseScreen(String exercise, String? sessionId, String groupId) {
  switch (exercise) {
    case 'match-definitions':
      return MatchDefinitionsScreen(sessionId: sessionId, groupId: groupId);
    case 'match-synonyms':
      return MatchSynonymsScreen(sessionId: sessionId, groupId: groupId);
    case 'pick-the-answer':
      return PickTheAnswerScreen(sessionId: sessionId, groupId: groupId);
    case 'remember-or-not':
      return RememberOrNotScreen(sessionId: sessionId, groupId: groupId);
    default:
      return ComingSoonScreen(exerciseId: exercise);
  }
}
