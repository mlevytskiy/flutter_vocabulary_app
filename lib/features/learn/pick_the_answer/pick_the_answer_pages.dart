import 'dart:math';

import '../../../core/models/word_pair.dart';
import '../exercises.dart';
import '../kit/question_builder.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'pick_the_answer_page_body.dart';

/// The two question kinds, taken A, B, A… (S-29).
const pickKinds = [QuestionKind.wordToTranslation, QuestionKind.meaningToWord];

/// The words of [group] that pick-the-answer can ask about (S-25): a question
/// exists for both kinds. Null never depends on the Random, so a fixed seed
/// finds the same words. Shared by [pickTheAnswerPages] and the old notifier
/// (learn-redesign ADR-0003).
List<WordPair> pickUsable(List<WordPair> group, QuestionPool pool) => <WordPair>[
      for (final word in group)
        if (pickKinds.every((k) => buildQuestion(word, pool, k, Random(0)) != null)) word,
    ];

final _exercise = exercises.firstWhere((e) => e.id == 'pick-the-answer');

/// Pick the right answer's page source (learn-redesign ADR-0003): one page per
/// usable word, kinds A, B, A… in word order. The first tap is final and the
/// page reports it through [PageAnswer.done].
Future<List<ExercisePage>> pickTheAnswerPages(PageInput input) async {
  final pool = QuestionPool(group: input.words, others: input.others);
  final usable = pickUsable(input.words, pool);
  return [
    for (var i = 0; i < usable.length; i++)
      if (buildQuestion(usable[i], pool, pickKinds[i % 2], input.random) case final question?)
        ExercisePage(
          exerciseId: _exercise.id,
          exerciseName: _exercise.name,
          step: _exercise.stage,
          rowIds: [usable[i].rowId],
          body: (context, answer) => PickTheAnswerSessionBody(
            question: question,
            kind: pickKinds[i % 2],
            answer: answer,
          ),
        ),
  ];
}
