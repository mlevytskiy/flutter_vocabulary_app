import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/guess_my_word/guess_my_word_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';

/// A Worker stand-in for kind `clues`: three clues by English word (null =
/// "none"); every call recorded.
class FakeCluesApi implements LearnApiService {
  FakeCluesApi([this.clues = const {}, this.error]);

  final Map<String, List<String>?> clues;
  Object? error;
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    expect(kind, same(LearnDataKind.clues));
    calls.add(words);
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: (clues.containsKey(w.word) ? clues[w.word] : ['a ${w.word}', 'b', 'c']) == null
            ? null
            : (clues: clues.containsKey(w.word) ? clues[w.word]! : ['one ${w.word}', 'two ${w.word}', 'three ${w.word}']) as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

/// learn-guess-my-word: clues, masking, rounds, scoring (AC-02 – AC-07, AC-09 –
/// AC-12, AC-14 – AC-24; S-51, S-52).
void main() {
  WordPair w(int i, {String? word, String? translation, String definition = ''}) => WordPair(
      word: word ?? 'word$i', translation: translation ?? 'слово$i', rowId: 'r$i', definition: definition);

  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];

  final provider = guessMyWordProvider(null, 'g');

  ProviderContainer open(List<WordPair> g, FakeCluesApi api, {int seed = 1}) {
    final c = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      learnApiServiceProvider.overrideWithValue(api),
      exerciseWordsProvider(null, 'g').overrideWith((ref) async => (group: g, others: const <WordPair>[])),
    ]);
    addTearDown(c.dispose);
    c.listen(provider, (_, __) {});
    return c;
  }

  Future<GuessState> load(ProviderContainer c) => c.read(provider.future);
  GuessMyWord notifier(ProviderContainer c) => c.read(provider.notifier);
  GuessState now(ProviderContainer c) => c.read(provider).requireValue;

  /// A word of the current round that is not the target and not greyed.
  String wrong(ProviderContainer c) {
    final s = now(c);
    return s.grid.firstWhere((x) => x.rowId != s.target!.rowId && !s.greyed.contains(x.rowId) && !s.points.containsKey(x.rowId)).rowId;
  }

  Future<void> pause() => Future<void>.delayed(const Duration(milliseconds: 650));

  group('opening and clues', () {
    test('AC-01, AC-02, AC-14: one call for exactly the candidates; grid and targets are the round, shuffled once', () async {
      final g = [...words(6), w(6, translation: '  ')];
      final api = FakeCluesApi();
      final c = open(g, api);
      final s = await load(c);
      expect(api.calls.length, 1);
      expect(api.calls.single.map((x) => x.rowId), ['r0', 'r1', 'r2', 'r3', 'r4', 'r5']);
      expect(api.calls.single.first, (rowId: 'r0', word: 'word0', translation: 'слово0'));
      expect(s.grid.map((x) => x.rowId), unorderedEquals(['r0', 'r1', 'r2', 'r3', 'r4', 'r5']));
      expect(s.targets.map((x) => x.rowId), unorderedEquals(['r0', 'r1', 'r2', 'r3', 'r4', 'r5']));
      expect(s.level, 1);
      expect((s.phase as ExerciseRound).count, 1);
      expect(s.target!.clues.length, 3);
    });

    test('AC-02: the same seed gives the same orders (1000 seeds); a round has its own', () async {
      final g = words(6);
      for (var seed = 0; seed < 1000; seed++) {
        final a = await load(open(g, FakeCluesApi(), seed: seed));
        final b = await load(open(g, FakeCluesApi(), seed: seed));
        expect(a.grid.map((x) => x.rowId).toList(), b.grid.map((x) => x.rowId).toList(), reason: 'seed $seed');
        expect(a.targets.map((x) => x.rowId).toList(), b.targets.map((x) => x.rowId).toList(), reason: 'seed $seed');
      }
    });

    test('AC-09: every clue is masked, forms in any case, not inside other words', () async {
      final g = [w(0, word: 'walk'), w(1), w(2)];
      final api = FakeCluesApi({
        'walk': ['Walk is fun', 'You walk the dog; Walking is good for you.', 'by the sidewalk'],
      });
      final s = await load(open(g, api));
      final walk = s.rounds.single.words.firstWhere((x) => x.rowId == 'r0');
      expect(walk.clues, ['___ is fun', 'You ___ the dog; ___ is good for you.', 'by the sidewalk']);
    });

    test('AC-10: clue 3 is the stored definition line, masked and cut; else the Worker clue', () async {
      final g = [
        w(0, word: 'bank', definition: 'definition: a place where you keep money\nexample: I went to the bank.'),
        w(1),
        w(2),
        w(3, word: 'river', definition: 'definition: the river is long, a river'),
      ];
      final api = FakeCluesApi({
        'bank': ['x bank', 'y', 'worker three'],
      });
      final s = await load(open(g, api));
      final byId = {for (final x in s.rounds.single.words) x.rowId: x};
      expect(byId['r0']!.clues, ['x ___', 'y', 'a place where you keep money']);
      expect(byId['r1']!.clues[2], 'three ___');
      expect(byId['r3']!.clues[2], 'the ___ is long, a ___');
      expect(api.calls.length, 1, reason: 'no definition call');
    });

    test('AC-11: a clue that is only the word leaves the word out; unusable stored clue 3 falls back', () async {
      final g = [w(0, word: 'walk'), w(1), w(2), w(3), w(4, word: 'tree', definition: 'tree')];
      final api = FakeCluesApi({
        'walk': ['Walk.', 'b', 'c'],
        'tree': ['one', 'two', 'worker three'],
      });
      final s = await load(open(g, api));
      expect(s.rounds.single.words.map((x) => x.rowId), ['r1', 'r2', 'r3', 'r4']);
      expect(s.rounds.single.words.last.clues[2], 'worker three');
    });

    test('AC-12: none, or a refused answer, leaves the word out', () async {
      final g = words(5);
      final api = FakeCluesApi({'word1': null});
      final s = await load(open(g, api));
      expect(s.rounds.single.words.map((x) => x.rowId), ['r0', 'r2', 'r3', 'r4']);
    });

    test('AC-15: a second equal word (any case, spaces) is not a candidate', () async {
      final g = [w(0, word: 'light'), w(1, word: ' Light '), w(2), w(3), w(4)];
      final api = FakeCluesApi();
      final s = await load(open(g, api));
      expect(api.calls.single.map((x) => x.rowId), ['r0', 'r2', 'r3', 'r4']);
      expect(s.grid.map((x) => x.rowId), isNot(contains('r1')));
    });
  });

  group('rounds, empty and error states', () {
    test('AC-16: round sizes', () async {
      for (final (n, sizes) in [
        (12, [6, 6]),
        (19, [7, 6, 6]),
        (9, [9]),
        (10, [5, 5]),
        (3, [3]),
      ]) {
        final s = await load(open(words(n), FakeCluesApi()));
        expect(s.rounds.map((r) => r.words.length), sizes, reason: '$n');
        if (sizes.length > 1) expect((s.phase as ExerciseRound).count, sizes.length);
      }
    });

    test('AC-17: fewer than 3 candidates: default line, no Worker call', () async {
      final api = FakeCluesApi();
      final s = await load(open([w(0), w(1), w(2, translation: '')], api));
      expect(api.calls, isEmpty);
      expect(s.phase, isA<ExerciseNotEnough>());
      expect((s.phase as ExerciseNotEnough).message, isNull);
    });

    test('AC-18: fewer than 3 usable: its own line', () async {
      final api = FakeCluesApi({'word0': null, 'word1': null});
      final s = await load(open(words(4), api));
      expect((s.phase as ExerciseNotEnough).message, 'Not enough words with clues for this group');
    });

    test('AC-19, AC-20: a throw fails the load; Retry asks again', () async {
      final api = FakeCluesApi({}, LearnApiException(LearnApiError.network, 'x'));
      final c = open(words(4), api);
      await expectLater(c.read(provider.future), throwsA(isA<LearnApiException>()));
      api.error = null;
      notifier(c).retry();
      final s = await load(c);
      expect(api.calls.length, 2);
      expect(s.phase, isA<ExerciseRound>());
    });
  });

  group('the round (S-52)', () {
    test('AC-03: a right tap on clue 1 scores 3, ignores taps, then opens the next target', () async {
      final c = open(words(6), FakeCluesApi());
      await load(c);
      final first = now(c).target!;
      notifier(c).tap(first.rowId);
      expect(now(c).points[first.rowId], 3);
      notifier(c).tap(wrong(c));
      expect(now(c).greyed, isEmpty, reason: 'locked');
      expect(now(c).targetIndex, 0);
      await pause();
      expect(now(c).targetIndex, 1);
      expect(now(c).level, 1);
      expect(now(c).greyed, isEmpty);
    });

    test('AC-04, AC-05: a wrong tap greys the word and shows the next clue; right on 2 and 3 score 2 and 1', () async {
      final c = open(words(6), FakeCluesApi());
      await load(c);
      final t = now(c).target!;
      final bad = wrong(c);
      notifier(c).tap(bad);
      expect(now(c).greyed, {bad});
      expect(now(c).level, 2);
      notifier(c).tap(bad);
      expect(now(c).level, 2, reason: 'greyed word is inert');
      notifier(c).tap(t.rowId);
      expect(now(c).points[t.rowId], 2);
      await pause();
      final t2 = now(c).target!;
      notifier(c).tap(wrong(c));
      notifier(c).tap(wrong(c));
      expect(now(c).level, 3);
      notifier(c).tap(t2.rowId);
      expect(now(c).points[t2.rowId], 1);
    });

    test('AC-06: a wrong tap on clue 3 scores 0, reveals; only Next moves on', () async {
      final c = open(words(6), FakeCluesApi());
      await load(c);
      final t = now(c).target!;
      for (var i = 0; i < 3; i++) {
        notifier(c).tap(wrong(c));
      }
      expect(now(c).revealed, isTrue);
      expect(now(c).points[t.rowId], 0);
      final before = now(c).greyed;
      notifier(c).tap(t.rowId);
      notifier(c).tap(wrong(c));
      expect(now(c).greyed, before);
      expect(now(c).points[t.rowId], 0);
      notifier(c).next();
      expect(now(c).targetIndex, 1);
      expect(now(c).revealed, isFalse);
      expect(now(c).level, 1);
    });

    test('AC-07: found words do nothing; greyed words come back for the next target', () async {
      final c = open(words(6), FakeCluesApi());
      await load(c);
      final bad = wrong(c);
      notifier(c).tap(bad);
      notifier(c).tap(now(c).target!.rowId);
      await pause();
      final found = now(c).targets.first.rowId;
      notifier(c).tap(found);
      expect(now(c).level, 1);
      expect(now(c).greyed, isEmpty);
      expect(now(c).points.length, 1);
    });

    test('AC-21, AC-22: summary in group order with the heading; Next round is fresh', () async {
      final c = open(words(12), FakeCluesApi());
      await load(c);
      // Round 1: targets score 0, 1, 2, 3, 3, 3 (late targets have few wrong words left).
      for (var i = 0; i < 6; i++) {
        final t = now(c).target!;
        final wrongTaps = switch (i) { 0 => 3, 1 => 2, 2 => 1, _ => 0 };
        for (var k = 0; k < wrongTaps; k++) {
          notifier(c).tap(wrong(c));
        }
        if (wrongTaps == 3) {
          notifier(c).next();
        } else {
          notifier(c).tap(t.rowId);
          await pause();
        }
      }
      final s = now(c);
      expect(s.inSummary, isTrue);
      final phase = s.phase as ExerciseSummary;
      expect(phase.hasNextRound, isTrue);
      expect(phase.outcomes.map((o) => o.rowId), ['r0', 'r1', 'r2', 'r3', 'r4', 'r5']);
      final total = s.targets.fold<int>(0, (a, t) => a + s.points[t.rowId]!);
      expect(phase.heading, 'Score: $total of 18');
      expect(phase.outcomes.map((o) => o.result), everyElement(isIn(['3 points', '2 points', '1 point', 'Not found'])));
      expect(phase.outcomes.map((o) => o.result).toSet(), {'3 points', '2 points', '1 point', 'Not found'});
      notifier(c).nextRound();
      final n = now(c);
      expect(n.round, 1);
      expect(n.targetIndex, 0);
      expect(n.points, isEmpty);
      expect(n.grid.map((x) => x.rowId), unorderedEquals(['r6', 'r7', 'r8', 'r9', 'r10', 'r11']));
    });

    test('AC-23: leaving cancels the pause; nothing fails after dispose', () async {
      final c = open(words(6), FakeCluesApi());
      await load(c);
      notifier(c).tap(now(c).target!.rowId);
      c.dispose();
      await pause();
    });
  });
}
