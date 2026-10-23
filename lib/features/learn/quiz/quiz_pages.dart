import 'dart:math';

import '../../../core/models/film_dialogue.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/models/word_result.dart';
import '../../../core/services/learn_api_service.dart';
import '../exercises.dart';
import '../kit/gap_question.dart';
import '../kit/question_builder.dart';
import '../kit/typed_answer_field.dart';
import '../session/exercise_page.dart';
import '../session/page_input.dart';
import 'quiz_page_body.dart';

/// The most questions in one attempt (S-54).
const quizMaxQuestions = 7;

/// One planned position of an attempt (S-54): the word, and the choice kind
/// it takes, or null for a gap question.
typedef QuizSlot = ({WordPair word, QuestionKind? kind});

/// The S-54 walk over [order] (already shuffled): at most 7 words from its
/// front; an odd position takes the first remaining word that [canChoose]
/// (else the first remaining word, as a gap), an even position the first
/// remaining word that [canGap] (else the first remaining word, as a
/// choice). Choice positions take kinds A, B, A… in their own order. Every
/// word in [order] must take at least one of the two. Pure.
List<QuizSlot> quizLayout(
  List<WordPair> order, {
  required bool Function(WordPair) canChoose,
  required bool Function(WordPair) canGap,
}) {
  final left = order.take(quizMaxQuestions).toList();
  final slots = <QuizSlot>[];
  var choices = 0;
  while (left.isNotEmpty) {
    final wantChoice = slots.length.isEven; // positions 1, 3, 5… from 0
    final at = left.indexWhere(wantChoice ? canChoose : canGap);
    final word = left.removeAt(at < 0 ? 0 : at);
    final choice = at < 0 ? !wantChoice : wantChoice;
    QuestionKind? kind;
    if (choice) kind = (choices++).isEven ? QuestionKind.wordToTranslation : QuestionKind.meaningToWord;
    slots.add((word: word, kind: kind));
  }
  return slots;
}

/// One question of an attempt: a choice question ([choice], [kind]) or a gap
/// question ([gap]).
class QuizQuestion {
  const QuizQuestion({required this.word, this.choice, this.kind, this.gap})
      : assert((choice == null) != (gap == null));

  final WordPair word;
  final Question? choice;
  final QuestionKind? kind;
  final GapQuestion? gap;

  String get rowId => word.rowId;

  /// The right answer as the summary shows it: the right option, or the word.
  String get right => choice != null ? choice!.options[choice!.rightIndex] : gap!.answer;
}

/// S-55 (3): a choice answer's label.
WordResultLabel choiceLabel(Question question, int picked) =>
    picked == question.rightIndex ? WordResultLabel.known : WordResultLabel.repeat;

/// S-55 (3): a typed answer's label; right and almost are known, wrong and Skip repeat.
WordResultLabel typedLabel(TypedAnswerResult result) =>
    result.match.isRight && !result.gaveUp ? WordResultLabel.known : WordResultLabel.repeat;

/// What the Quiz loaded at open (S-53), kept for Repeat attempts (no new read
/// or call).
class QuizData {
  const QuizData({required this.pool, required this.choosable, required this.gaps, required this.gapsUnavailable});

  final QuestionPool pool;

  /// Row ids of the words that take a choice question of both kinds (S-25).
  final Set<String> choosable;
  final Map<String, GapQuestion> gaps;

  /// The gap load failed: the Quiz asks choice questions only.
  final bool gapsUnavailable;

  bool canChoose(WordPair w) => choosable.contains(w.rowId);
  bool canGap(WordPair w) => gaps.containsKey(w.rowId);
}


/// The words of [group] the Quiz can take at all: a row id, a word and a
/// translation.
List<WordPair> quizCandidates(List<WordPair> group) => <WordPair>[
      for (final w in group)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty) w,
    ];

/// What the Quiz loads for [candidates] (S-53): which take a choice question
/// and their gap questions. Shared by [quizPages] and the old notifier
/// (learn-redesign ADR-0003).
Future<QuizData> loadQuizData(
  List<WordPair> candidates, {
  required List<WordPair> group,
  required List<WordPair> others,
  required List<FilmDialogue> dialogues,
  required LearnApiService api,
}) async {
  final pool = QuestionPool(group: group, others: others);
  // S-25: whether a question can be built never depends on the Random.
  final choosable = {
    for (final w in candidates)
      if (QuestionKind.values.every((k) => buildQuestion(w, pool, k, Random(0)) != null)) w.rowId,
  };
  var gaps = const <String, GapQuestion>{};
  var gapsUnavailable = false;
  try {
    gaps = await loadGapQuestions(candidates, dialogues, api);
  } catch (_) {
    // S-53: any gap failure degrades to choice questions only.
    gapsUnavailable = true;
  }
  return QuizData(pool: pool, choosable: choosable, gaps: gaps, gapsUnavailable: gapsUnavailable);
}

/// The [candidates] that take a choice or a gap question.
List<WordPair> quizUsable(QuizData data, List<WordPair> candidates) =>
    [for (final w in candidates) if (data.canChoose(w) || data.canGap(w)) w];

/// The question of one layout slot, a choice question built with [random].
QuizQuestion quizQuestion(QuizData data, QuizSlot s, Random random) => s.kind == null
    ? QuizQuestion(word: s.word, gap: data.gaps[s.word.rowId])
    : QuizQuestion(word: s.word, kind: s.kind, choice: buildQuestion(s.word, data.pool, s.kind!, random));

final _exercise = exercises.firstWhere((e) => e.id == 'quiz');

/// The Quiz's page source (learn-redesign ADR-0003): one page per usable word,
/// laid out by the S-54 rule seven words at a time. A choice page is done on
/// its first tap; a gap page is ready once something is typed and its check
/// uses the typed-answer match. Session pages never record a word result
/// (AC-15): only the old notifier writes to the exam result sink.
Future<List<ExercisePage>> quizPages(PageInput input) async {
  final candidates = quizCandidates(input.words);
  if (candidates.isEmpty) return const [];
  final data = await loadQuizData(
    candidates,
    group: input.words,
    others: input.others,
    dialogues: input.dialogues,
    api: input.api,
  );
  final usable = quizUsable(data, candidates);
  final pages = <ExercisePage>[];
  for (var i = 0; i < usable.length; i += quizMaxQuestions) {
    final slice = usable.sublist(i, min(i + quizMaxQuestions, usable.length));
    for (final slot in quizLayout(slice, canChoose: data.canChoose, canGap: data.canGap)) {
      final question = quizQuestion(data, slot, input.random);
      pages.add(ExercisePage(
        exerciseId: _exercise.id,
        exerciseName: _exercise.name,
        step: _exercise.stage,
        rowIds: [question.rowId],
        body: (context, answer) => QuizSessionBody(question: question, answer: answer),
      ));
    }
  }
  return pages;
}
