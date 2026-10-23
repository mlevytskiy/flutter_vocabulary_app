import 'dart:math';

import '../../../core/models/film_dialogue.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/services/learn_api_service.dart';

/// What every exercise's page source gets (learn-redesign ADR-0003): the
/// session's [words], the collection's [others] (distractors, as an
/// exercise's `others` today), its film [dialogues], the exercise data
/// service and the session's seeded [random].
///
/// A page source is a top-level function
/// `Future<List<ExercisePage>> <exercise>Pages(PageInput input)` holding the
/// question building cut from its exercise notifier's `build`; the notifier
/// calls the same function. It returns no page for a word it cannot ask
/// about, and throws [LearnApiException] when its AI data cannot be loaded
/// (the session shows the error line and plays the other pages, AC-11).
class PageInput {
  const PageInput({
    required this.words,
    required this.others,
    required this.dialogues,
    required this.api,
    required this.random,
  });

  final List<WordPair> words;
  final List<WordPair> others;
  final List<FilmDialogue> dialogues;
  final LearnApiService api;
  final Random random;
}
