import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/word_pair.dart';
import '../../../core/models/word_result.dart';
import '../../../core/providers.dart';
import '../kit/exercise_phase.dart';
import '../kit/exercise_random.dart';
import '../kit/exercise_words.dart';
import '../kit/result_summary.dart';
import '../kit/typed_answer_field.dart';
import 'quiz_pages.dart';

export 'quiz_pages.dart'
    show QuizData, QuizQuestion, QuizSlot, choiceLabel, quizLayout, quizMaxQuestions, typedLabel;

part 'quiz_notifier.g.dart';

/// The frozen exercise id the Quiz records its word results under (S-02, S-55).
const quizExerciseId = 'quiz';

/// The final answer to one question (S-55): its [label], the learner's
/// [given] answer (null = skipped) and the option [picked] on a choice question.
class QuizAnswer {
  const QuizAnswer({required this.label, this.given, this.picked});

  final WordResultLabel label;
  final String? given;
  final int? picked;
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
  // Riverpod 2's rule: every new state notifies (toolchain-upgrade).
  @override
  bool updateShouldNotify(AsyncValue<QuizState> previous, AsyncValue<QuizState> next) =>
      asyncNotifyAsBefore(previous, next);

  late Random _random;

  @override
  Future<QuizState> build(String? collectionId, String groupId) async {
    _random = ref.read(exerciseRandomProvider);
    final words = await ref.watch(exerciseWordsProvider(collectionId, groupId).future);
    final dialogues = await ref.watch(exerciseDialoguesProvider(collectionId).future);
    final candidates = quizCandidates(words.group);
    if (candidates.length < 3) return const QuizState();

    final data = await loadQuizData(
      candidates,
      group: words.group,
      others: words.others,
      dialogues: dialogues,
      api: ref.read(learnApiServiceProvider),
    );
    final usable = quizUsable(data, candidates);
    if (usable.length < 3) return const QuizState();
    return _attempt(data, usable, 0);
  }

  /// A new attempt over [words] by the S-54 rule, all questions built now.
  QuizState _attempt(QuizData data, List<WordPair> words, int attempt) {
    final order = [...words]..shuffle(_random);
    final slots = quizLayout(order, canChoose: data.canChoose, canGap: data.canGap);
    final questions = [for (final s in slots) quizQuestion(data, s, _random)];
    return QuizState(data: data, questions: questions, answers: List.filled(questions.length, null), attempt: attempt);
  }

  void retry() {
    ref.invalidate(exerciseWordsProvider(collectionId, groupId));
    ref.invalidate(exerciseDialoguesProvider(collectionId));
    ref.invalidateSelf();
  }

  /// The first tap on an option is final (AC-12).
  void pick(int option) {
    final q = state.value?.question;
    if (q?.choice == null) return;
    _final(QuizAnswer(label: choiceLabel(q!.choice!, option), given: q.choice!.options[option], picked: option));
  }

  /// A typed answer sent, or the exam field's Skip (AC-14 – AC-17).
  void submit(TypedAnswerResult result) {
    final q = state.value?.question;
    if (q?.gap == null) return;
    _final(QuizAnswer(label: typedLabel(result), given: result.gaveUp ? null : result.answer.trim()));
  }

  /// Skip on any open question: repeat (AC-17).
  void skip() => _final(const QuizAnswer(label: WordResultLabel.repeat));

  /// S-55 (1): the answer becomes final and its result is recorded in the
  /// same step, once per question of an attempt, never awaited.
  void _final(QuizAnswer answer) {
    final s = state.value;
    final q = s?.question;
    if (s == null || q == null || s.answer != null) return;
    state = AsyncData(s._with(answers: [...s.answers]..[s.index] = answer));
    unawaited(ref.read(examResultSinkProvider).record(
          collectionId: collectionId,
          rowId: q.rowId,
          exerciseId: quizExerciseId,
          label: answer.label,
        ));
  }

  /// The next question, or the summary after the last (AC-18). Records nothing.
  void next() {
    final s = state.value;
    if (s == null || s.answer == null) return;
    state = AsyncData(s._with(answers: s.answers, index: s.index + 1));
  }

  /// "Repeat" on the summary (AC-25, AC-26): a new attempt over exactly the
  /// repeat words, from the data loaded at open.
  void repeat() {
    final s = state.value;
    final data = s?.data;
    if (s == null || data == null || !s.inSummary) return;
    final words = s.repeatWords;
    if (words.isEmpty) return;
    state = AsyncData(_attempt(data, words, s.attempt + 1));
  }
}
