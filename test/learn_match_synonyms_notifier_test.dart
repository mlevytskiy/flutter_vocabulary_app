import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/match_rounds.dart';
import 'package:flutter_vocabulary_app/features/learn/match_synonyms/match_synonyms_notifier.dart';

/// A Worker stand-in: the synonym of each word by its English text (null =
/// "none"), every call recorded.
class FakeLearnApi implements LearnApiService {
  FakeLearnApi(this.synonyms, {this.error});

  final Map<String, String?> synonyms;
  Object? error;
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    expect(kind, same(LearnDataKind.synonym));
    calls.add(words);
    if (error != null) throw error!;
    return {
      for (final w in words) w.rowId: synonyms[w.word] == null ? null : (synonym: synonyms[w.word]!) as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

/// The kit's usable-words loop over the Worker's synonym answers (S-41).
List<MatchPair> usableSynonymPairs(List<WordPair> words, Map<String, SynonymData?> answers) =>
    usableMatchPairs(words, {for (final e in answers.entries) e.key: e.value?.synonym});

/// learn-match-synonyms: usable words, rounds, shuffle, pairing, misses and
/// the summary (AC-02, AC-03, AC-04, AC-06, AC-08 – AC-12, AC-15 – AC-18,
/// AC-20, AC-21; S-34, S-36, S-38, S-39).
void main() {
  WordPair w(int i, {String? word, String? translation}) =>
      WordPair(word: word ?? 'word$i', translation: translation ?? 'слово$i', rowId: 'r$i');

  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];
  Map<String, String?> syn(List<WordPair> g) => {for (final x in g) x.word: 'syn ${x.rowId}'};

  final provider = matchSynonymsProvider(null, 'g');

  /// [listen] keeps the auto-disposed exercise alive across awaits, as the
  /// open screen does.
  ProviderContainer open(List<WordPair> g, FakeLearnApi api, {int seed = 1, bool listen = true}) {
    final c = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      learnApiServiceProvider.overrideWithValue(api),
      exerciseWordsProvider(null, 'g').overrideWith((ref) async => (group: g, others: const <WordPair>[])),
    ]);
    addTearDown(c.dispose);
    if (listen) c.listen(provider, (_, __) {});
    return c;
  }
  Future<MatchRoundsState> load(ProviderContainer c) => c.read(provider.future);
  MatchSynonyms notifier(ProviderContainer c) => c.read(provider.notifier);
  MatchRoundsState now(ProviderContainer c) => c.read(provider).requireValue;

  /// Links every pair of the current round.
  void solve(ProviderContainer c) {
    for (final item in now(c).left) {
      expect(notifier(c).pair(item.id, item.id), isTrue);
    }
  }

  group('opening and the board', () {
    test('AC-01, AC-02: 6 words, one round, left in group order, right exactly their synonyms', () async {
      final g = words(6);
      final c = open(g, FakeLearnApi(syn(g)));
      final s = await load(c);
      expect(s.phase, isA<ExerciseRound>());
      expect((s.phase as ExerciseRound).count, 1);
      expect(s.left.map((x) => x.text), ['word0', 'word1', 'word2', 'word3', 'word4', 'word5']);
      expect(s.left.map((x) => x.hint), ['слово0', 'слово1', 'слово2', 'слово3', 'слово4', 'слово5']);
      expect(s.right.map((x) => x.id), unorderedEquals(s.left.map((x) => x.id)));
      for (final r in s.right) {
        expect(r.text, 'syn ${r.id}');
        expect(r.hint, isNull, reason: 'a synonym has no hint (AC-14)');
      }
      expect(s.right.map((x) => x.id), isNot(orderedEquals(s.left.map((x) => x.id))));
    });

    test('AC-02, §6 determinism: same seed, same right order; never in left order over 1000 seeds', () async {
      final g = words(3);
      final orders = <String>{};
      for (var seed = 0; seed < 1000; seed++) {
        final c = open(g, FakeLearnApi(syn(g)), seed: seed);
        final s = await load(c);
        final order = s.right.map((x) => x.id).join(',');
        expect(order, isNot('r0,r1,r2'), reason: 'seed $seed');
        orders.add(order);
        final again = open(g, FakeLearnApi(syn(g)), seed: seed);
        expect((await load(again)).right.map((x) => x.id).join(','), order);
        c.dispose();
        again.dispose();
      }
      expect(orders.length, greaterThan(1));
    });

    test('AC-03, AC-22: one Worker call for the whole group with word, translation and rowId', () async {
      final g = [w(0, word: ' big ', translation: 'великий'), w(1), w(2), w(3)];
      final api = FakeLearnApi({'big': 'large', 'word1': 'a', 'word2': 'b', 'word3': 'c'});
      final c = open(g, api);
      await load(c);
      expect(api.calls.length, 1);
      expect(api.calls.single, [
        (rowId: 'r0', word: 'big', translation: 'великий'),
        (rowId: 'r1', word: 'word1', translation: 'слово1'),
        (rowId: 'r2', word: 'word2', translation: 'слово2'),
        (rowId: 'r3', word: 'word3', translation: 'слово3'),
      ]);
      solve(c);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      notifier(c).nextRound();
      expect(api.calls.length, 1, reason: 'no call during rounds or the summary');
    });
  });

  group('usable words (S-38)', () {
    test('AC-09: a word the Worker has no synonym for is left out', () async {
      final g = [w(0, word: 'tripod'), w(1), w(2), w(3), w(4), w(5)];
      final s = await load(open(g, FakeLearnApi({...syn(g), 'tripod': null})));
      expect(s.left.map((x) => x.text), ['word1', 'word2', 'word3', 'word4', 'word5']);
      expect(s.rounds.length, 1);
    });

    test('AC-10: clashing synonyms and words: the earlier word stays', () {
      final g = [
        w(0, word: 'big'),
        w(1, word: 'huge'),
        w(2, word: 'car'),
        w(3, word: 'automobile'),
        w(4, word: 'dog'),
      ];
      final answers = <String, SynonymData?>{
        'r0': (synonym: 'large'),
        'r1': (synonym: 'Large  '),
        'r2': (synonym: 'automobile'),
        'r3': (synonym: 'car'),
        'r4': (synonym: 'hound'),
      };
      expect(usableSynonymPairs(g, answers).map((p) => p.word), ['big', 'car', 'dog']);
    });

    test('AC-11: the same English word twice keeps only the first', () {
      final g = [w(0, word: 'bank', translation: 'банк'), w(1, word: 'Bank', translation: 'берег'), w(2), w(3)];
      final answers = <String, SynonymData?>{
        'r0': (synonym: 'lender'),
        'r1': (synonym: 'shore'),
        'r2': (synonym: 'a'),
        'r3': (synonym: 'b'),
      };
      final kept = usableSynonymPairs(g, answers);
      expect(kept.map((p) => p.rowId), ['r0', 'r2', 'r3']);
    });

    test('AC-12: a synonym that holds the word itself is left out', () {
      final g = [w(0, word: 'house'), w(1), w(2), w(3)];
      final answers = <String, SynonymData?>{
        'r0': (synonym: 'small house'),
        'r1': (synonym: 'a'),
        'r2': (synonym: 'b'),
        'r3': (synonym: 'c'),
      };
      expect(usableSynonymPairs(g, answers).map((p) => p.rowId), ['r1', 'r2', 'r3']);
    });

    test('AC-09: a word missing from the answers is left out', () {
      final g = [w(0), w(1)];
      expect(usableSynonymPairs(g, {'r1': (synonym: 'x')}).map((p) => p.rowId), ['r1']);
    });

    test('§6 fairness: no board with equal cards or a second right card over 1000 seeds', () async {
      final g = [
        w(0, word: 'big'), w(1, word: 'huge'), w(2, word: 'large'), w(3, word: 'car'),
        w(4, word: 'automobile'), w(5, word: 'bank'), w(6, word: 'bank'), w(7, word: 'house'),
        w(8, word: 'dog'), w(9, word: 'fast'), w(10, word: 'quick'), w(11, word: 'speedy'),
        w(12, word: 'begin'), w(13, word: 'start'),
      ];
      final api = FakeLearnApi({
        'big': 'large', 'huge': 'LARGE', 'large': 'big', 'car': 'automobile', 'automobile': 'car',
        'bank': 'lender', 'house': 'houses', 'dog': 'hound', 'fast': 'quick', 'quick': 'rapid',
        'speedy': 'rapid', 'begin': 'start', 'start': 'commence',
      });
      String norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      for (var seed = 0; seed < 1000; seed++) {
        final c = open(g, api, seed: seed);
        final s = await load(c);
        for (var r = 0; r < s.rounds.length; r++) {
          final cards = [...s.rounds[r].left.map((x) => norm(x.text)), ...s.rounds[r].right.map((x) => norm(x.text))];
          expect(cards.toSet().length, cards.length, reason: 'seed $seed round $r: $cards');
        }
        c.dispose();
      }
    });
  });

  group('rounds, empty and error states', () {
    test('AC-15: 8 → 4+4, 7 → 4+3, 13 → 5+4+4, 6 → 6', () async {
      for (final (n, sizes) in [(8, [4, 4]), (7, [4, 3]), (13, [5, 4, 4]), (6, [6])]) {
        final g = words(n);
        final s = await load(open(g, FakeLearnApi(syn(g))));
        expect(s.rounds.map((r) => r.left.length), sizes, reason: '$n words');
        expect(s.rounds.expand((r) => r.left).map((x) => x.id), [for (var i = 0; i < n; i++) 'r$i']);
        expect((s.phase as ExerciseRound).count, sizes.length);
      }
    });

    test('AC-16: fewer than 3 usable after the answers shows the synonym line', () async {
      final g = words(4);
      final s = await load(open(g, FakeLearnApi({'word0': 'a', 'word1': 'b'})));
      final phase = s.phase as ExerciseNotEnough;
      expect(phase.message, 'Not enough words with synonyms for this group');
    });

    test('AC-17: fewer than 3 words to learn shows the default line and asks nobody', () async {
      for (final g in [words(2), <WordPair>[]]) {
        final api = FakeLearnApi(syn(g));
        final s = await load(open(g, api));
        expect((s.phase as ExerciseNotEnough).message, isNull);
        expect(api.calls, isEmpty);
      }
    });

    test('AC-18: a failed load is an error; Retry asks again and opens round 1', () async {
      final g = words(4);
      final api = FakeLearnApi(syn(g), error: LearnApiException(LearnApiError.network, 'offline'));
      final c = open(g, api);
      await expectLater(load(c), throwsA(isA<LearnApiException>()));
      expect(failureOf(c.read(provider).error!), ExerciseFailure.network);
      api.error = null;
      notifier(c).retry();
      final s = await load(c);
      expect(s.phase, isA<ExerciseRound>());
      expect(api.calls.length, 2);
    });
  });

  group('pairing and the summary', () {
    test('AC-04: a right pair is linked in order, no miss counted; a locked pair takes no second link', () async {
      final g = words(4);
      final c = open(g, FakeLearnApi(syn(g)));
      await load(c);
      expect(notifier(c).pair('r2', 'r2'), isTrue);
      expect(notifier(c).pair('r0', 'r0'), isTrue);
      expect(now(c).links.entries.map((e) => e.key), ['r2', 'r0']);
      expect(now(c).misses, isEmpty);
      expect(notifier(c).pair('r2', 'r1'), isFalse);
      expect(now(c).misses, isEmpty, reason: 'a locked card never counts');
    });

    test('AC-06: each wrong try counts one miss on the word', () async {
      final g = words(4);
      final c = open(g, FakeLearnApi(syn(g)));
      await load(c);
      expect(notifier(c).pair('r0', 'r1'), isFalse);
      expect(notifier(c).pair('r0', 'r2'), isFalse);
      expect(notifier(c).pair('r1', 'r0'), isFalse);
      expect(now(c).misses, {'r0': 2, 'r1': 1});
      expect(now(c).links, isEmpty);
    });

    test('AC-08, AC-20: the summary opens about 500 ms after the last link, with misses in group order', () async {
      final g = words(8);
      final c = open(g, FakeLearnApi(syn(g)));
      await load(c);
      notifier(c).pair('r0', 'r1');
      notifier(c).pair('r0', 'r2');
      notifier(c).pair('r1', 'r3');
      solve(c);
      expect(now(c).phase, isA<ExerciseRound>(), reason: 'the last lock shows first');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(now(c).phase, isA<ExerciseRound>());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final summary = now(c).phase as ExerciseSummary;
      expect(summary.heading, isNull);
      expect(summary.hasNextRound, isTrue);
      expect(summary.outcomes.map((o) => (o.word, o.result)), [
        ('word0', '2 misses'),
        ('word1', '1 miss'),
        ('word2', 'no misses'),
        ('word3', 'no misses'),
      ]);
      notifier(c).nextRound();
      expect(now(c).phase, isA<ExerciseRound>());
      expect((now(c).phase as ExerciseRound).index, 1);
      expect(now(c).links, isEmpty);
      expect(now(c).misses, isEmpty);
      expect(now(c).left.map((x) => x.id), ['r4', 'r5', 'r6', 'r7']);
      solve(c);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect((now(c).phase as ExerciseSummary).hasNextRound, isFalse);
    });

    test('AC-21: opening again starts at round 1 with nothing linked and no misses', () async {
      final g = words(8);
      final api = FakeLearnApi(syn(g));
      final c = open(g, api, listen: false);
      final sub = c.listen(provider, (_, __) {});
      await load(c);
      notifier(c).pair('r0', 'r1');
      notifier(c).pair('r0', 'r0');
      sub.close();
      await Future<void>.delayed(Duration.zero);
      final s = await load(c);
      expect((s.phase as ExerciseRound).index, 0);
      expect(s.links, isEmpty);
      expect(s.misses, isEmpty);
    });
  });
}
