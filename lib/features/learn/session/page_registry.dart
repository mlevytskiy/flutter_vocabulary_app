import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exercises.dart';
import '../explain_to_friend/explain_to_friend_pages.dart';
import '../fill_the_gaps/fill_the_gaps_pages.dart';
import '../guess_my_word/guess_my_word_pages.dart';
import '../match_definitions/match_definitions_pages.dart';
import '../match_synonyms/match_synonyms_pages.dart';
import '../own_sentences/own_sentences_pages.dart';
import '../pick_the_answer/pick_the_answer_pages.dart';
import '../quiz/quiz_pages.dart';
import '../remember_or_not/remember_or_not_pages.dart';
import '../sentence_patterns/sentence_patterns_pages.dart';
import '../translate_sentences/translate_sentences_pages.dart';
import 'exercise_page.dart';
import 'page_input.dart';

/// One exercise's page source (learn-redesign ADR-0003).
typedef PageSource = Future<List<ExercisePage>> Function(PageInput input);

/// The page source of each of the eleven page exercises (`pageExerciseIds`):
/// Mnemonic story and Dialogs from movie open their own screens and are never
/// session pages (AC-08).
const Map<String, PageSource> pageSources = {
  'match-synonyms': matchSynonymsPages,
  'match-definitions': matchDefinitionsPages,
  'guess-my-word': guessMyWordPages,
  'pick-the-answer': pickTheAnswerPages,
  'fill-the-gaps': fillTheGapsPages,
  'remember-or-not': rememberOrNotPages,
  'sentence-patterns': sentencePatternsPages,
  'own-sentences': ownSentencesPages,
  'translate-sentences': translateSentencesPages,
  'explain-to-friend': explainToFriendPages,
  'quiz': quizPages,
};

/// The page sources a learning session draws from; tests override it with
/// fake sources.
final pageSourcesProvider = Provider<Map<String, PageSource>>((ref) => pageSources);

/// The step (1 Meet, 2 Practise, 3 Use) of exercise [id].
int stepOf(String id) => exercises.firstWhere((e) => e.id == id).stage;
