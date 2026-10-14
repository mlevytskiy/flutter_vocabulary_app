import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/models/word_result.dart';
import '../../../core/providers.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/gap_question.dart';
import '../kit/question_builder.dart';
import '../kit/result_summary.dart';
import '../kit/typed_answer_field.dart';

part 'quiz_notifier.g.dart';

/// The frozen exercise id the Quiz records its word results under (S-02, S-55).
const quizExerciseId = 'quiz';

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

/// The final answer to one question (S-55): its [label], the learner's
/// [given] answer (null = skipped) and the option [picked] on a choice question.
class QuizAnswer {
  const QuizAnswer({required this.label, this.given, this.picked});

  final WordResultLabel label;
  final String? given;
  final int? picked;
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
}

/// Where the Quiz stands (S-53 – S-56). [data] is null when there are not
/// enough words. [questions] are the current attempt's, [answers] their
/// final answers (null while open), [index] the question shown; [index] =
/// questions.length is the summary. [attempt] counts attempts (keys fields).
class QuizState {
  const QuizState({
    this.data,
    this.questions = const [],
    this.answers = const [],
    this.index = 0,
    this.attempt = 0,
  });

  final QuizData? data;
  final List<QuizQuestion> questions;
  final List<QuizAnswer?> answers;
  final int index;
  final int attempt;

  bool get gapsUnavailable => data?.gapsUnavailable ?? false;
  bool get inSummary => questions.isNotEmpty && index >= questions.length;
  QuizQuestion? get question => questions.isEmpty || inSummary ? null : questions[index];
  QuizAnswer? get answer => question == null ? null : answers[index];

  /// The words labelled repeat in this attempt, in asked order.
  List<WordPair> get repeatWords => [
        for (var i = 0; i < questions.length; i++)
          if (answers[i]?.label == WordResultLabel.repeat) questions[i].word,
      ];

  ExercisePhase get phase {
    if (data == null || questions.isEmpty) return const ExerciseNotEnough();
    if (!inSummary) return const ExerciseRound(0, 1);
    final known = answers.where((a) => a?.label == WordResultLabel.known).length;
    return ExerciseSummary(
      [
        for (var i = 0; i < questions.length; i++)
          WordOutcome(
            rowId: questions[i].rowId,
            word: questions[i].word.word.trim(),
            result: answers[i]?.label == WordResultLabel.known ? 'Known' : 'Repeat',
            detail: answers[i]?.label == WordResultLabel.known
                ? null
                : 'Answer: ${questions[i].right} · ${answers[i]?.given == null ? 'Skipped' : 'Yours: ${answers[i]!.given}'}',
          ),
      ],
      hasNextRound: false,
      heading: examHeading(known, questions.length),
      againLabel: known < questions.length ? 'Repeat' : null,
    );
  }

  QuizState _with({required List<QuizAnswer?> answers, int? index}) =>
      QuizState(data: data, questions: questions, answers: answers, index: index ?? this.index, attempt: attempt);
}

/// The Quiz of one group (learn-quiz): a short exam of up to 7 mixed
/// questions. Each final answer records the word's result through
/// [examResultSinkProvider] at once (S-55); nothing else is saved.
/// Auto-disposed, so leaving the screen forgets the attempt.
@riverpod
class Quiz extends _$Quiz {
  late Random _random;

  @override
  Future<QuizState> build(String? sessionId, String groupId) async {
    _random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(sessionId, groupId).future);
    final dialogues = await ref.watch(exerciseDialoguesProvider(sessionId).future);
    final candidates = <WordPair>[
      for (final w in words.group)
        if (w.rowId.isNotEmpty && w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty) w,
    ];
    if (candidates.length < 3) return const QuizState();

    final pool = QuestionPool(group: words.group, others: words.others);
    // S-25: whether a question can be built never depends on the Random.
    final choosable = {
      for (final w in candidates)
        if (QuestionKind.values.every((k) => buildQuestion(w, pool, k, Random(0)) != null)) w.rowId,
    };
    var gaps = const <String, GapQuestion>{};
    var gapsUnavailable = false;
    try {
      gaps = await loadGapQuestions(candidates, dialogues, ref.read(learnApiServiceProvider));
    } catch (_) {
      // S-53: any gap failure degrades to choice questions only.
      gapsUnavailable = true;
    }
    final data = QuizData(pool: pool, choosable: choosable, gaps: gaps, gapsUnavailable: gapsUnavailable);
    final usable = [for (final w in candidates) if (_canChoose(data, w) || _canGap(data, w)) w];
    if (usable.length < 3) return const QuizState();
    return _attempt(data, usable, 0);
  }

  bool _canChoose(QuizData data, WordPair w) => data.choosable.contains(w.rowId);
  bool _canGap(QuizData data, WordPair w) => data.gaps.containsKey(w.rowId);

  /// A new attempt over [words] by the S-54 rule, all questions built now.
  QuizState _attempt(QuizData data, List<WordPair> words, int attempt) {
    final order = [...words]..shuffle(_random);
    final slots = quizLayout(order, canChoose: (w) => _canChoose(data, w), canGap: (w) => _canGap(data, w));
    final questions = [
      for (final s in slots)
        s.kind == null
            ? QuizQuestion(word: s.word, gap: data.gaps[s.word.rowId])
            : QuizQuestion(word: s.word, kind: s.kind, choice: buildQuestion(s.word, data.pool, s.kind!, _random)),
    ];
    return QuizState(data: data, questions: questions, answers: List.filled(questions.length, null), attempt: attempt);
  }

  void retry() {
    ref.invalidate(exerciseWordsProvider(sessionId, groupId));
    ref.invalidate(exerciseDialoguesProvider(sessionId));
    ref.invalidateSelf();
  }

  /// The first tap on an option is final (AC-12).
  void pick(int option) {
    final q = state.valueOrNull?.question;
    if (q?.choice == null) return;
    _final(QuizAnswer(label: choiceLabel(q!.choice!, option), given: q.choice!.options[option], picked: option));
  }

  /// A typed answer sent, or the exam field's Skip (AC-14 – AC-17).
  void submit(TypedAnswerResult result) {
    final q = state.valueOrNull?.question;
    if (q?.gap == null) return;
    _final(QuizAnswer(label: typedLabel(result), given: result.gaveUp ? null : result.answer.trim()));
  }

  /// Skip on any open question: repeat (AC-17).
  void skip() => _final(const QuizAnswer(label: WordResultLabel.repeat));

  /// S-55 (1): the answer becomes final and its result is recorded in the
  /// same step, once per question of an attempt, never awaited.
  void _final(QuizAnswer answer) {
    final s = state.valueOrNull;
    final q = s?.question;
    if (s == null || q == null || s.answer != null) return;
    state = AsyncData(s._with(answers: [...s.answers]..[s.index] = answer));
    unawaited(ref.read(examResultSinkProvider).record(
          sessionId: sessionId,
          rowId: q.rowId,
          exerciseId: quizExerciseId,
          label: answer.label,
        ));
  }

  /// The next question, or the summary after the last (AC-18). Records nothing.
  void next() {
    final s = state.valueOrNull;
    if (s == null || s.answer == null) return;
    state = AsyncData(s._with(answers: s.answers, index: s.index + 1));
  }

  /// "Repeat" on the summary (AC-25, AC-26): a new attempt over exactly the
  /// repeat words, from the data loaded at open.
  void repeat() {
    final s = state.valueOrNull;
    final data = s?.data;
    if (s == null || data == null || !s.inSummary) return;
    final words = s.repeatWords;
    if (words.isEmpty) return;
    state = AsyncData(_attempt(data, words, s.attempt + 1));
  }
}
