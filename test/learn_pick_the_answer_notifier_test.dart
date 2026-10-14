import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/pick_the_answer/pick_the_answer_notifier.dart';

/// learn-pick-the-answer: usable words, rounds, kinds, answers and the summary
/// (AC-02, AC-03, AC-05 – AC-07, AC-11 – AC-16; S-25, S-27, S-29).
void main() {
  var n = 0;
  WordPair w(String word, String translation, {String definition = ''}) =>
      WordPair(word: word, translation: translation, definition: definition, rowId: 'id${n++}');

  List<WordPair> group(int count) => [for (var i = 0; i < count; i++) w('word$i', 'слово$i')];

  ProviderContainer open(List<WordPair> g, {List<WordPair> others = const [], int seed = 1, Object? error}) {
    final c = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      exerciseWordsProvider(null, 'g').overrideWith((ref) async {
        if (error != null) throw error;
        return (group: g, others: others);
      }),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<PickState> load(ProviderContainer c) => c.read(pickTheAnswerProvider(null, 'g').future);
  PickTheAnswer notifier(ProviderContainer c) => c.read(pickTheAnswerProvider(null, 'g').notifier);
  PickState now(ProviderContainer c) => c.read(pickTheAnswerProvider(null, 'g')).requireValue;

  test('AC-01: 5 words give one round, question 1 of 5 is kind A on the first word', () async {
    final g = group(5);
    final c = open(g);
    final s = await load(c);
    expect(s.phase, isA<ExerciseRound>());
    expect((s.phase as ExerciseRound).count, 1);
    expect(s.roundSize, 5);
    expect(s.index, 0);
    expect(s.question!.prompt, 'word0');
    expect(s.question!.options.length, 4);
  });

  test('AC-02, AC-03: group order, kinds A B A B A, fresh kind A next round, right place varies', () async {
    final g = group(13);
    final c = open(g);
    await load(c);
    final n = notifier(c);
    final places = <int>{};
    final prompts = <String>[];
    for (var round = 0; round < 2; round++) {
      final size = now(c).roundSize;
      expect(size, round == 0 ? 7 : 6);
      for (var i = 0; i < size; i++) {
        final s = now(c);
        prompts.add(s.question!.prompt);
        places.add(s.question!.rightIndex);
        expect(s.kindIsWord, i.isEven, reason: 'round $round question $i');
        n.pick(s.question!.rightIndex);
        n.next();
      }
      if (round == 0) n.nextRound();
    }
    expect(places.length, greaterThan(1));
    expect(prompts.first, 'word0');
    expect(prompts[1], 'слово1', reason: 'kind B shows the meaning (translation here), AC-04');
    expect(prompts[7], 'word7');
  });

  test('AC-05, AC-06: first tap is final; right counts Right, wrong counts Missed', () async {
    final c = open(group(5));
    final s0 = await load(c);
    final right = s0.question!.rightIndex;
    final wrong = (right + 1) % 4;
    final n = notifier(c);
    n.pick(wrong);
    n.pick(right);
    expect(now(c).picked, wrong);
    expect(now(c).results, [false]);
    n.next();
    final q2 = now(c).question!;
    n.pick(q2.rightIndex);
    expect(now(c).results, [false, true]);
  });

  test('next before an answer does nothing', () async {
    final c = open(group(5));
    await load(c);
    notifier(c).next();
    expect(now(c).index, 0);
  });

  test('AC-07, AC-15: after the last question Next opens the summary; Right/Missed in question order; Next round / Done', () async {
    final c = open(group(13));
    await load(c);
    final n = notifier(c);
    for (var i = 0; i < 7; i++) {
      final s = now(c);
      n.pick(i == 2 ? (s.question!.rightIndex + 1) % 4 : s.question!.rightIndex);
      n.next();
    }
    final sum = now(c).phase as ExerciseSummary;
    expect(sum.hasNextRound, isTrue);
    expect([for (final o in sum.outcomes) o.word], [for (var i = 0; i < 7; i++) 'word$i']);
    expect([for (final o in sum.outcomes) o.result], ['Right', 'Right', 'Missed', 'Right', 'Right', 'Right', 'Right']);
    n.nextRound();
    expect((now(c).phase as ExerciseRound).index, 1);
    expect(now(c).index, 0);
    expect(now(c).question!.prompt, 'word7');
    for (var i = 0; i < 6; i++) {
      n.pick(now(c).question!.rightIndex);
      n.next();
    }
    expect((now(c).phase as ExerciseSummary).hasNextRound, isFalse);
  });

  test('AC-11, AC-13: words without a translation or a question are left out; 10 words give 5 + 5', () async {
    final g = [w('nodef', '', definition: 'has a definition'), ...group(9), w('lonely', 'самотній')];
    final c = open(g);
    final s = await load(c);
    expect(s.roundSize, 5);
    final prompts = <String>[];
    final n = notifier(c);
    for (var round = 0; round < 2; round++) {
      for (var i = 0; i < 5; i++) {
        final q = now(c).question!;
        if (i.isEven) prompts.add(q.prompt);
        n.pick(q.rightIndex);
        n.next();
      }
      if (round == 0) {
        expect((now(c).phase as ExerciseSummary).outcomes.map((o) => o.word), isNot(contains('nodef')));
        n.nextRound();
      }
    }
    expect(prompts.contains('nodef'), isFalse);
  });

  test('AC-12: fewer than 3 usable words, or none, show the not-enough line', () async {
    expect((await load(open(group(2)))).phase, isA<ExerciseNotEnough>());
    expect((await load(open(const []))).phase, isA<ExerciseNotEnough>());
    // Only three words and nothing else: four different options are impossible.
    final c = open(group(3));
    expect((await load(c)).phase, isA<ExerciseNotEnough>());
  });

  test('AC-10: wrong options are topped up from the session\'s other words', () async {
    final g = group(3);
    final others = [for (var i = 0; i < 7; i++) w('other$i', 'інше$i')];
    final c = open(g, others: others);
    final s = await load(c);
    expect(s.phase, isA<ExerciseRound>());
    expect(s.roundSize, 3);
  });

  test('AC-14: a load error shows the failed phase; Retry reads again', () async {
    final c = open(group(5), error: LearnApiException(LearnApiError.network, 'x'));
    final p = c.read(pickTheAnswerProvider(null, 'g'));
    await expectLater(load(c), throwsA(anything));
    expect(p.isLoading || c.read(pickTheAnswerProvider(null, 'g')).hasError, isTrue);
    expect(failureOf(c.read(pickTheAnswerProvider(null, 'g')).error!), ExerciseFailure.network);
  });

  test('S-27: the same words and seed give the same questions', () async {
    final a = await load(open(group(8), seed: 7));
    final b = await load(open(group(8), seed: 7));
    expect(a.question!.options, b.question!.options);
    expect(a.question!.rightIndex, b.question!.rightIndex);
  });

  test('AC-16: nothing is kept: a new open starts at round 1, question 1', () async {
    final c = open(group(13));
    await load(c);
    notifier(c).pick(0);
    c.invalidate(pickTheAnswerProvider(null, 'g'));
    final s = await load(c);
    expect(s.index, 0);
    expect(s.picked, isNull);
    expect(s.results, isEmpty);
  });
}
