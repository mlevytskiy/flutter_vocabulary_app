import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/fill_the_gaps/fill_the_gaps_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_answer_field.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_match.dart';

/// learn-fill-the-gaps: usable words, rounds, results and the summary
/// (AC-15, AC-20 – AC-23, AC-26, AC-27; S-46).
class _Api implements LearnApiService {
  Object? error;
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    if (error != null) throw error!;
    return {for (final w in words) w.rowId: (sentence: 'We ${w.word} it on the day.') as T};
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected: ${i.memberName}');
}

TypedAnswerResult _first = const TypedAnswerResult(match: TypedMatch.right, answer: 'x', firstTry: true, gaveUp: false);
TypedAnswerResult _second = const TypedAnswerResult(match: TypedMatch.right, answer: 'x', firstTry: false, gaveUp: false);
TypedAnswerResult _almost = const TypedAnswerResult(match: TypedMatch.almost, answer: 'x', firstTry: true, gaveUp: false);
TypedAnswerResult _missed = const TypedAnswerResult(match: TypedMatch.wrong, answer: 'x', firstTry: false, gaveUp: false);
TypedAnswerResult _shown = const TypedAnswerResult(match: TypedMatch.wrong, answer: '', firstTry: false, gaveUp: true);

void main() {
  late _Api api;

  WordPair w(int i, {String? word, String? translation}) =>
      WordPair(word: word ?? 'word$i', translation: translation ?? 'слово$i', rowId: 'r$i');

  ProviderContainer open(List<WordPair> g, {List<FilmDialogue> dialogues = const []}) {
    api = _Api();
    final c = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      exerciseWordsProvider(null, 'g').overrideWith((ref) async => (group: g, others: const <WordPair>[])),
      exerciseDialoguesProvider(null).overrideWith((ref) async => dialogues),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<FillState> load(ProviderContainer c) => c.read(fillTheGapsProvider(null, 'g').future);
  FillTheGaps notifier(ProviderContainer c) => c.read(fillTheGapsProvider(null, 'g').notifier);
  FillState now(ProviderContainer c) => c.read(fillTheGapsProvider(null, 'g')).requireValue;

  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];

  void answer(ProviderContainer c, TypedAnswerResult r) {
    notifier(c).answer(r);
    notifier(c).next();
  }

  group('opening', () {
    test('AC-21: rounds of 3 to 9 in group order', () async {
      Future<List<int>> sizes(int n) async => [for (final r in (await load(open(words(n)))).rounds) r.length];
      expect(await sizes(12), [6, 6]);
      expect(await sizes(19), [7, 6, 6]);
      expect(await sizes(9), [9]);
      expect(await sizes(3), [3]);
      final s = await load(open(words(12)));
      expect(s.rounds.first.map((q) => q.rowId), [for (var i = 0; i < 6; i++) 'r$i']);
      expect(s.phase, isA<ExerciseRound>());
    });

    test('AC-22: under 3 words to learn: not enough and no call', () async {
      for (final n in [0, 2]) {
        final c = open(words(n));
        expect((await load(c)).phase, isA<ExerciseNotEnough>());
        expect(api.calls, isEmpty);
      }
    });

    test('AC-20/23: words without a translation are never sent; under 3 usable is not enough', () async {
      final c = open([w(0), w(1), w(2, translation: ' '), w(3, translation: '')]);
      expect((await load(c)).phase, isA<ExerciseNotEnough>());
      expect(api.calls, isEmpty);
    });

    test('AC-15: one call for the words without a dialogue sentence only', () async {
      final d = FilmDialogue()
        ..id = 'd'
        ..lines = ['We word0 it on the day.']
        ..wordRowIds = ['r0'];
      final c = open(words(4), dialogues: [d]);
      final s = await load(c);
      expect(api.calls, hasLength(1));
      expect(api.calls.single.map((x) => x.rowId), ['r1', 'r2', 'r3']);
      expect(s.rounds.single, hasLength(4));
    });

    test('AC-15: all dialogue sentences: no call', () async {
      final d = FilmDialogue()
        ..id = 'd'
        ..lines = [for (var i = 0; i < 3; i++) 'We word$i it on the day.']
        ..wordRowIds = ['r0', 'r1', 'r2'];
      final c = open(words(3), dialogues: [d]);
      await load(c);
      expect(api.calls, isEmpty);
    });

    test('AC-24: a failed call fails the whole exercise; retry asks again', () async {
      final c = open(words(3));
      api.error = LearnApiException(LearnApiError.network, 'down');
      await expectLater(load(c), throwsA(isA<LearnApiException>()));
      expect(failureOf(c.read(fillTheGapsProvider(null, 'g')).error!), ExerciseFailure.network);
      api.error = null;
      notifier(c).retry();
      final s = await load(c);
      expect(s.phase, isA<ExerciseRound>());
      expect(api.calls, hasLength(2));
    });
  });

  group('answering', () {
    test('S-46: points and labels; Next moves on; no call during questions', () async {
      final c = open(words(5));
      await load(c);
      expect(now(c).question!.rowId, 'r0');
      expect(now(c).result, isNull);
      notifier(c).answer(_first);
      expect(now(c).result, same(_first));
      notifier(c).answer(_missed); // a final answer stays
      expect(now(c).result, same(_first));
      notifier(c).next();
      expect(now(c).question!.rowId, 'r1');
      expect(now(c).result, isNull);
      notifier(c).next(); // Next before an answer does nothing
      expect(now(c).question!.rowId, 'r1');
      notifier(c).answer(_first);
      notifier(c).next();
      answer(c, _second);
      answer(c, _shown);
      answer(c, _almost);
      expect(api.calls, hasLength(1));
      final phase = now(c).phase as ExerciseSummary;
      expect(phase.heading, 'Score: 7 of 10');
      expect(phase.outcomes.map((o) => o.result), ['1st try', '1st try', '2nd try', 'Missed', '1st try']);
      expect(phase.outcomes.map((o) => o.word), [for (var i = 0; i < 5; i++) 'word$i']);
      expect(phase.hasNextRound, isFalse);
    });

    test('AC-26: 1st, 1st, 2nd, shown, almost-first scores 7 of 10', () async {
      final c = open(words(5));
      await load(c);
      for (final r in [_first, _first, _second, _shown, _almost]) {
        answer(c, r);
      }
      // 2 + 2 + 1 + 0 + 2
      expect((now(c).phase as ExerciseSummary).heading, 'Score: 7 of 10');
    });

    test('a wrong final answer is Missed; almost on a second try is 2nd try', () async {
      final c = open(words(3));
      await load(c);
      answer(c, _missed);
      answer(c, const TypedAnswerResult(match: TypedMatch.almost, answer: 'x', firstTry: false, gaveUp: false));
      answer(c, _first);
      final p = now(c).phase as ExerciseSummary;
      expect(p.outcomes.map((o) => o.result), ['Missed', '2nd try', '1st try']);
      expect(p.heading, 'Score: 3 of 6');
    });

    test('rounds: Next round shows the next round with a fresh state; the heading counts that round', () async {
      final c = open(words(12));
      await load(c);
      for (var i = 0; i < 6; i++) {
        answer(c, _first);
      }
      final p = now(c).phase as ExerciseSummary;
      expect(p.hasNextRound, isTrue);
      expect(p.heading, 'Score: 12 of 12');
      notifier(c).nextRound();
      final s = now(c);
      expect(s.phase, isA<ExerciseRound>());
      expect((s.phase as ExerciseRound).index, 1);
      expect(s.question!.rowId, 'r6');
      for (var i = 0; i < 6; i++) {
        answer(c, _missed);
      }
      final last = now(c).phase as ExerciseSummary;
      expect(last.hasNextRound, isFalse);
      expect(last.heading, 'Score: 0 of 12');
      notifier(c).nextRound(); // no round left: nothing
      expect(now(c).phase, isA<ExerciseSummary>());
    });

    test('AC-27: opening again starts at question 1 of round 1', () async {
      final c = open(words(3));
      await load(c);
      answer(c, _first);
      c.invalidate(fillTheGapsProvider(null, 'g'));
      final s = await load(c);
      expect(s.index, 0);
      expect(s.round, 0);
      expect(s.result, isNull);
    });
  });
}
