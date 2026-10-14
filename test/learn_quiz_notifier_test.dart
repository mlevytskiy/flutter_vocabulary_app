import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/exam_result_sink.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/question_builder.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_answer_field.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_match.dart';
import 'package:flutter_vocabulary_app/features/learn/quiz/quiz_notifier.dart';

/// learn-quiz: usable words, layout, exam answers, word results, summary and
/// Repeat (AC-02 – AC-09, AC-12, AC-14 – AC-21, AC-23 – AC-26; S-53 – S-56).

/// Answers "We <word> it on the day." for every word not in [noSentence].
class _Api implements LearnApiService {
  Object? error;
  final noSentence = <String>{};
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    if (error != null) throw error!;
    return {
      for (final w in words) w.rowId: noSentence.contains(w.word) ? null : (sentence: 'We ${w.word} it on the day.') as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected: ${i.memberName}');
}

typedef _Record = ({String? sessionId, String rowId, String exerciseId, WordResultLabel label});

/// Records every call; [record] never completes (the quiz must not wait for it).
class _Sink implements ExamResultSink {
  final records = <_Record>[];

  @override
  Future<void> record({
    required String? sessionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  }) {
    records.add((sessionId: sessionId, rowId: rowId, exerciseId: exerciseId, label: label));
    return Completer<void>().future;
  }

  @override
  Map<String, WordResult> latest(Session session) => const {};
}

const _right = TypedAnswerResult(match: TypedMatch.right, answer: ' word ', firstTry: true, gaveUp: false);
const _almost = TypedAnswerResult(match: TypedMatch.almost, answer: 'wrod', firstTry: true, gaveUp: false);
const _wrong = TypedAnswerResult(match: TypedMatch.wrong, answer: ' accept ', firstTry: false, gaveUp: false);
const _skipped = TypedAnswerResult(match: TypedMatch.wrong, answer: '', firstTry: false, gaveUp: true);

void main() {
  late _Api api;
  late _Sink sink;

  WordPair w(int i, {String? word, String? translation, String? rowId}) =>
      WordPair(word: word ?? 'word$i', translation: translation ?? 'слово$i', rowId: rowId ?? 'r$i');
  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];
  final others = [for (var i = 0; i < 3; i++) w(100 + i, word: 'other$i', translation: 'інше$i')];

  ProviderContainer open(
    List<WordPair> group, {
    List<FilmDialogue> dialogues = const [],
    String? sessionId,
    int seed = 1,
    List<WordPair>? otherWords,
  }) {
    api = _Api();
    sink = _Sink();
    final c = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      examResultSinkProvider.overrideWithValue(sink),
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      exerciseWordsProvider(sessionId, 'g').overrideWith((ref) async => (group: group, others: otherWords ?? others)),
      exerciseDialoguesProvider(sessionId).overrideWith((ref) async => dialogues),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<QuizState> load(ProviderContainer c, {String? sessionId}) => c.read(quizProvider(sessionId, 'g').future);
  Quiz notifier(ProviderContainer c, {String? sessionId}) => c.read(quizProvider(sessionId, 'g').notifier);
  QuizState now(ProviderContainer c, {String? sessionId}) => c.read(quizProvider(sessionId, 'g')).requireValue;

  /// Answers the current question right (or wrong) and moves on.
  void answer(ProviderContainer c, {bool right = true, String? sessionId}) {
    final n = notifier(c, sessionId: sessionId);
    final q = now(c, sessionId: sessionId).question!;
    if (q.choice != null) {
      final r = q.choice!.rightIndex;
      n.pick(right ? r : (r + 1) % 4);
    } else {
      n.submit(right ? _right : _wrong);
    }
    n.next();
  }

  group('layout (S-54, AC-05)', () {
    final a = w(0, word: 'a'), b = w(1, word: 'b'), c = w(2, word: 'c'), d = w(3, word: 'd');

    test('a, b choice only, c both, d gap only: a A, c gap, b B, d gap', () {
      final plan = quizLayout([a, b, c, d], canChoose: (x) => x != d, canGap: (x) => x == c || x == d);
      expect(plan.map((p) => p.word.word), ['a', 'c', 'b', 'd']);
      expect(plan.map((p) => p.kind), [QuestionKind.wordToTranslation, null, QuestionKind.meaningToWord, null]);
    });

    test('all choice only: kinds A, B, A…; all gap only: gaps only', () {
      final choice = quizLayout([a, b, c, d], canChoose: (_) => true, canGap: (_) => false);
      expect(choice.map((p) => p.kind), [
        QuestionKind.wordToTranslation,
        QuestionKind.meaningToWord,
        QuestionKind.wordToTranslation,
        QuestionKind.meaningToWord,
      ]);
      final gaps = quizLayout([a, b, c], canChoose: (_) => false, canGap: (_) => true);
      expect(gaps.map((p) => p.kind), [null, null, null]);
      expect(gaps.map((p) => p.word.word), ['a', 'b', 'c']);
    });

    test('at most 7, taken from the front of the order', () {
      final plan = quizLayout(words(12), canChoose: (_) => true, canGap: (_) => true);
      expect(plan.map((p) => p.word.rowId), [for (var i = 0; i < 7; i++) 'r$i']);
    });
  });

  group('opening (S-53)', () {
    test('AC-01: 9 words: 7 questions on 7 different words, choice A, gap, B, gap, A, gap, B', () async {
      final s = await load(open(words(9)));
      expect(s.phase, isA<ExerciseRound>());
      expect(s.questions, hasLength(7));
      expect(s.questions.map((q) => q.rowId).toSet(), hasLength(7));
      expect(s.questions.map((q) => q.kind), [
        QuestionKind.wordToTranslation,
        null,
        QuestionKind.meaningToWord,
        null,
        QuestionKind.wordToTranslation,
        null,
        QuestionKind.meaningToWord,
      ]);
      expect([for (final q in s.questions) q.gap != null], [false, true, false, true, false, true, false]);
      expect(s.gapsUnavailable, isFalse);
    });

    test('AC-02: 3, 5, 6, 7 and 12 usable words ask 3, 5, 6, 7, 7, never twice', () async {
      for (final (n, m) in [(3, 3), (5, 5), (6, 6), (7, 7), (12, 7)]) {
        final s = await load(open(words(n)));
        expect(s.questions, hasLength(m), reason: '$n words');
        expect(s.questions.map((q) => q.rowId).toSet(), hasLength(m));
      }
    });

    test('AC-03: under 3 candidates: not enough and no Worker call', () async {
      for (final g in [
        words(2),
        [w(0), w(1), w(2, translation: ' ')],
        [w(0), w(1), w(2, rowId: '')],
      ]) {
        final c = open(g);
        expect((await load(c)).phase, isA<ExerciseNotEnough>());
        expect(api.calls, isEmpty);
      }
    });

    test('AC-04: 3 candidates but under 3 usable: not enough', () async {
      // Two homographs with no sentence take neither question.
      final c = open([w(0), w(1, word: 'bank'), w(2, word: 'bank')], otherWords: const []);
      api.noSentence.add('bank');
      expect((await load(c)).phase, isA<ExerciseNotEnough>());
    });

    test('AC-05: gap-only words give only gaps; a word that takes neither is never asked', () async {
      // One shared meaning: no kind B question can be built for any of them.
      final c = open([for (final x in [...words(4), w(10, word: 'none')]) x..definition = 'the same thing'],
          otherWords: const []);
      api.noSentence.add('none');
      final s = await load(c);
      expect(s.questions.map((q) => q.rowId), isNot(contains('r10')));
      expect(s.questions, hasLength(4));
      expect(s.questions.every((q) => q.gap != null), isTrue);
    });

    test('AC-06: same seed, same group: same words, order, kinds and options', () async {
      Future<List<String>> shape() async {
        final s = await load(open(words(12), seed: 42));
        return [
          for (final q in s.questions) '${q.rowId}|${q.kind}|${q.choice?.options.join(',')}|${q.gap?.masked}',
        ];
      }

      expect(await shape(), await shape());
    });

    test('AC-07: dialogue gaps first; one Worker call for the other words only; none when all have one', () async {
      final d = FilmDialogue()
        ..id = 'd'
        ..lines = [for (var i = 0; i < 3; i++) 'We word$i it on the day.']
        ..wordRowIds = ['r0', 'r1', 'r2'];
      final c = open(words(8), dialogues: [d]);
      await load(c);
      expect(api.calls, hasLength(1));
      expect(api.calls.single.map((x) => x.rowId), ['r3', 'r4', 'r5', 'r6', 'r7']);

      final all = FilmDialogue()
        ..id = 'd'
        ..lines = [for (var i = 0; i < 3; i++) 'We word$i it on the day.']
        ..wordRowIds = ['r0', 'r1', 'r2'];
      final c2 = open(words(3), dialogues: [all]);
      await load(c2);
      expect(api.calls, isEmpty);
    });

    test('AC-07: a word without a translation is never sent', () async {
      final c = open([...words(4), w(9, translation: '')]);
      await load(c);
      expect(api.calls.single.map((x) => x.rowId), isNot(contains('r9')));
    });

    test('AC-08: a failed gap load runs choice only and says so; gap-only words are not asked', () async {
      for (final e in [
        LearnApiException(LearnApiError.network, ''),
        LearnApiException(LearnApiError.timeout, ''),
        LearnApiException(LearnApiError.dayLimit, ''),
        LearnApiException(LearnApiError.rateLimited, ''),
        LearnApiException(LearnApiError.unavailable, ''),
        LearnApiException(LearnApiError.failed, ''),
      ]) {
        final c = open(words(9));
        api.error = e;
        final s = await load(c);
        expect(s.phase, isA<ExerciseRound>(), reason: '${e.error}');
        expect(s.gapsUnavailable, isTrue);
        expect(s.questions, hasLength(7));
        expect(s.questions.every((q) => q.choice != null), isTrue);
        expect(s.questions.map((q) => q.kind).take(3),
            [QuestionKind.wordToTranslation, QuestionKind.meaningToWord, QuestionKind.wordToTranslation]);
      }
    });

    test('AC-08: dialogue gaps are dropped too; under 3 choice words is not enough', () async {
      final d = FilmDialogue()
        ..id = 'd'
        ..lines = ['We word0 it on the day.']
        ..wordRowIds = ['r0'];
      final c = open(words(5), dialogues: [d]);
      api.error = LearnApiException(LearnApiError.network, '');
      expect((await load(c)).questions.every((q) => q.gap == null), isTrue);

      // Gap-only words (one shared meaning): with the gaps gone, no choice word is left.
      final c2 = open([for (final x in words(4)) x..definition = 'the same thing'], otherWords: const []);
      api.error = LearnApiException(LearnApiError.network, '');
      expect((await load(c2)).phase, isA<ExerciseNotEnough>());
    });

    test('AC-09: a failed word read is the error frame; Retry reads again', () async {
      api = _Api();
      sink = _Sink();
      var fail = true;
      final c = ProviderContainer(overrides: [
        learnApiServiceProvider.overrideWithValue(api),
        examResultSinkProvider.overrideWithValue(sink),
        exerciseRandomProvider.overrideWithValue(Random(1)),
        exerciseWordsProvider(null, 'g').overrideWith((ref) async {
          if (fail) throw StateError('read');
          return (group: words(5), others: others);
        }),
        exerciseDialoguesProvider(null).overrideWith((ref) async => const <FilmDialogue>[]),
      ]);
      addTearDown(c.dispose);
      await expectLater(load(c), throwsA(isA<StateError>()));
      expect(failureOf(c.read(quizProvider(null, 'g')).error!), ExerciseFailure.failed);
      fail = false;
      notifier(c).retry();
      expect((await load(c)).phase, isA<ExerciseRound>());
    });
  });

  group('answering and word results (S-55)', () {
    test('AC-12, AC-19: the first tap is final and records once, at once', () async {
      final c = open(words(7));
      await load(c);
      final q = now(c).question!;
      expect(q.choice, isNotNull);
      notifier(c).pick(q.choice!.rightIndex);
      expect(now(c).answer!.picked, q.choice!.rightIndex);
      expect(sink.records, [(sessionId: null, rowId: q.rowId, exerciseId: 'quiz', label: WordResultLabel.known)]);
      notifier(c).pick((q.choice!.rightIndex + 1) % 4);
      notifier(c).skip();
      expect(now(c).answer!.picked, q.choice!.rightIndex);
      expect(sink.records, hasLength(1));
    });

    test('a wrong option is repeat', () async {
      final c = open(words(7));
      await load(c);
      final q = now(c).question!;
      notifier(c).pick((q.choice!.rightIndex + 1) % 4);
      expect(sink.records.single.label, WordResultLabel.repeat);
    });

    test('AC-14, AC-15: typed right and almost are known, wrong and Skip are repeat', () async {
      for (final (r, label) in [
        (_right, WordResultLabel.known),
        (_almost, WordResultLabel.known),
        (_wrong, WordResultLabel.repeat),
        (_skipped, WordResultLabel.repeat),
      ]) {
        final c = open(words(7));
        await load(c);
        answer(c);
        expect(now(c).question!.gap, isNotNull);
        notifier(c).submit(r);
        notifier(c).submit(_right); // a final answer stays
        expect(sink.records, hasLength(2));
        expect(sink.records.last.label, label);
      }
    });

    test('AC-17: Skip on a choice question is final and repeat', () async {
      final c = open(words(7));
      await load(c);
      notifier(c).skip();
      expect(now(c).answer, isNotNull);
      expect(sink.records.single.label, WordResultLabel.repeat);
      notifier(c).pick(0);
      expect(sink.records, hasLength(1));
    });

    test('AC-18: Next needs a final answer; after the last question opens the summary', () async {
      final c = open(words(4));
      await load(c);
      notifier(c).next();
      expect(now(c).index, 0);
      for (var i = 0; i < 4; i++) {
        answer(c);
      }
      expect(now(c).phase, isA<ExerciseSummary>());
    });

    test('AC-20: one result per asked word over the whole attempt; none from Next or the summary', () async {
      final c = open(words(9));
      await load(c);
      for (var i = 0; i < 7; i++) {
        final before = sink.records.length;
        answer(c);
        expect(sink.records.length, before + 1);
      }
      expect(now(c).phase, isA<ExerciseSummary>());
      expect(sink.records, hasLength(7));
      expect(sink.records.map((r) => r.rowId).toSet(), now(c).questions.map((q) => q.rowId).toSet());
      expect(sink.records.every((r) => r.exerciseId == 'quiz'), isTrue);
    });

    test('AC-21: leaving after 3 answers leaves exactly 3 results; opening again starts fresh', () async {
      final c = open(words(9));
      await load(c);
      for (var i = 0; i < 3; i++) {
        answer(c);
      }
      c.invalidate(quizProvider(null, 'g'));
      final s = await load(c);
      expect(sink.records, hasLength(3));
      expect(s.index, 0);
      expect(s.answer, isNull);
    });

    test('AC-10: a History session id is passed through', () async {
      final c = open(words(5), sessionId: 'hist');
      await load(c, sessionId: 'hist');
      answer(c, sessionId: 'hist');
      expect(sink.records.single.sessionId, 'hist');
    });
  });

  group('summary and Repeat (S-56)', () {
    test('AC-23: heading, words in asked order, labels and detail lines; Repeat offered', () async {
      final c = open(words(7));
      await load(c);
      final asked = now(c).questions;
      // 1 (choice) skipped, 2 (gap) answered "accept", the rest right.
      notifier(c).skip();
      notifier(c).next();
      notifier(c).submit(_wrong);
      notifier(c).next();
      for (var i = 2; i < 7; i++) {
        answer(c);
      }
      final p = now(c).phase as ExerciseSummary;
      expect(p.heading, '5 of 7 known');
      expect(p.outcomes.map((o) => o.rowId), asked.map((q) => q.rowId));
      expect(p.outcomes.map((o) => o.result), ['Repeat', 'Repeat', 'Known', 'Known', 'Known', 'Known', 'Known']);
      final choice = asked[0].choice!;
      expect(p.outcomes[0].detail, 'Answer: ${choice.options[choice.rightIndex]} · Skipped');
      expect(p.outcomes[1].detail, 'Answer: ${asked[1].gap!.answer} · Yours: accept');
      expect(p.outcomes.skip(2).every((o) => o.detail == null), isTrue);
      expect(p.againLabel, 'Repeat');
      expect(p.hasNextRound, isFalse);
    });

    test('a wrong option shows the picked text', () async {
      final c = open(words(3));
      await load(c);
      final q = now(c).question!.choice!;
      final wrong = (q.rightIndex + 1) % 4;
      notifier(c).pick(wrong);
      notifier(c).next();
      answer(c);
      answer(c);
      final p = now(c).phase as ExerciseSummary;
      expect(p.outcomes.first.detail, 'Answer: ${q.options[q.rightIndex]} · Yours: ${q.options[wrong]}');
    });

    test('AC-24: all known: n of n known and no Repeat; repeat() does nothing', () async {
      final c = open(words(3));
      await load(c);
      for (var i = 0; i < 3; i++) {
        answer(c);
      }
      final p = now(c).phase as ExerciseSummary;
      expect(p.heading, '3 of 3 known');
      expect(p.againLabel, isNull);
      notifier(c).repeat();
      expect(now(c).phase, isA<ExerciseSummary>());
    });

    test('AC-25, AC-26: Repeat asks exactly the repeat words, no call, records again', () async {
      final c = open(words(7));
      await load(c);
      final asked = now(c).questions;
      for (var i = 0; i < 7; i++) {
        answer(c, right: i != 1 && i != 4);
      }
      final repeatIds = {asked[1].rowId, asked[4].rowId};
      notifier(c).repeat();
      final s = now(c);
      expect(s.phase, isA<ExerciseRound>());
      expect(s.questions.map((q) => q.rowId).toSet(), repeatIds);
      expect(s.index, 0);
      expect(s.answer, isNull);
      expect(api.calls, hasLength(1));
      expect(s.questions.first.choice, isNotNull, reason: 'the same layout rule: position 1 is choice');
      answer(c, right: false);
      answer(c);
      expect(sink.records, hasLength(9));
      final p = now(c).phase as ExerciseSummary;
      expect(p.outcomes, hasLength(2));
      expect(p.heading, '1 of 2 known');
      expect(p.againLabel, 'Repeat');
      notifier(c).repeat();
      expect(now(c).questions, hasLength(1));
    });

    test('AC-26: a Repeat attempt without gaps still says so and asks choice only', () async {
      final c = open(words(5));
      api.error = LearnApiException(LearnApiError.network, '');
      await load(c);
      for (var i = 0; i < 5; i++) {
        answer(c, right: false);
      }
      notifier(c).repeat();
      expect(now(c).gapsUnavailable, isTrue);
      expect(now(c).questions, hasLength(5));
      expect(now(c).questions.every((q) => q.choice != null), isTrue);
    });

    test('a Repeat attempt keys its questions apart from the first', () async {
      final c = open(words(3));
      await load(c);
      final first = now(c).attempt;
      for (var i = 0; i < 3; i++) {
        answer(c, right: false);
      }
      notifier(c).repeat();
      expect(now(c).attempt, isNot(first));
    });
  });
}
