import '../../../core/models/word_pair.dart';
import '../kit/gap_question.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'fill_the_gaps_page_body.dart';

/// The words fill-the-gaps can ask about: a word and a translation.
List<WordPair> gapCandidates(List<WordPair> words) => <WordPair>[
      for (final w in words)
        if (w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty) w,
    ];

/// The gap questions for [PageInput.words] in input order (S-44), cut from
/// the fill-the-gaps notifier's `build` (learn-redesign ADR-0003); a word
/// without a fair sentence gets none. A [LearnApiException] propagates.
Future<List<GapQuestion>> fillTheGapsQuestions(PageInput input) async {
  final questions = await loadGapQuestions(gapCandidates(input.words), input.dialogues, input.api);
  return questions.values.toList();
}

/// One step-2 page per word with a gap question (ADR-0003, AC-08). Check is
/// ready once the typed answer is final and counts right only when it was
/// right on the first try (AC-10).
Future<List<ExercisePage>> fillTheGapsPages(PageInput input) async => [
      for (final q in await fillTheGapsQuestions(input))
        ExercisePage(
          exerciseId: 'fill-the-gaps',
          exerciseName: 'Fill the gaps',
          step: 2,
          rowIds: [q.rowId],
          body: (context, answer) => FillTheGapsPageBody(
            question: q,
            onAnswered: (r) => answer.ready(() async => {q.rowId: r.firstTry}),
          ),
        ),
    ];
