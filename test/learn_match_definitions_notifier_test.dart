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
import 'package:flutter_vocabulary_app/features/learn/match_definitions/match_definitions_notifier.dart';

/// A Worker stand-in: the definition of each word by its English text (null =
/// "none"), every call recorded.
class FakeLearnApi implements LearnApiService {
  FakeLearnApi(this.definitions, {this.error});

  final Map<String, String?> definitions;
  Object? error;
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    expect(kind, same(LearnDataKind.definition));
    calls.add(words);
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: definitions[w.word] == null ? null : (definition: definitions[w.word]!) as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

/// learn-match-definitions: where a definition comes from, fair cards, rounds
/// and the empty and error states (AC-01, AC-02, AC-07 – AC-10, AC-13, AC-15
/// – AC-19, AC-21; S-38 – S-42).
void main() {
  WordPair w(int i, {String? word, String? translation, String? definition}) => WordPair(
      word: word ?? 'word$i', translation: translation ?? 'слово$i', rowId: 'r$i', definition: definition ?? 'meaning $i');

  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];

  final provider = matchDefinitionsProvider(null, 'g');

  ProviderContainer open(List<WordPair> g, FakeLearnApi api, {int seed = 1}) {
    final c = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      learnApiServiceProvider.overrideWithValue(api),
      exerciseWordsProvider(null, 'g').overrideWith((ref) async => (group: g, others: const <WordPair>[])),
    ]);
    addTearDown(c.dispose);
    c.listen(provider, (_, __) {});
    return c;
  }

  Future<MatchRoundsState> load(ProviderContainer c) => c.read(provider.future);
  MatchDefinitions notifier(ProviderContainer c) => c.read(provider.notifier);
  MatchRoundsState now(ProviderContainer c) => c.read(provider).requireValue;

  /// Links every pair of the current round.
  void solve(ProviderContainer c) {
    for (final item in now(c).left) {
      expect(notifier(c).pair(item.id, item.id), isTrue);
    }
  }

  group('opening and the board', () {
    test('AC-01, AC-02: stored definitions: no Worker call, left in group order, right exactly the definitions', () async {
      final g = words(6);
      final api = FakeLearnApi({});
      final s = await load(open(g, api));
      expect(api.calls, isEmpty);
      expect((s.phase as ExerciseRound).count, 1);
      expect(s.left.map((x) => x.text), ['word0', 'word1', 'word2', 'word3', 'word4', 'word5']);
      expect(s.left.map((x) => x.hint), everyElement(isNull));
      expect(s.right.map((x) => x.id), unorderedEquals(s.left.map((x) => x.id)));
      for (final r in s.right) {
        expect(r.text, 'meaning ${r.id.substring(1)}');
        expect(r.hint, isNull);
      }
      expect(s.right.map((x) => x.id), isNot(orderedEquals(s.left.map((x) => x.id))));
    });

    test('AC-02: the same seed gives the same right order; never in left order over 1000 seeds', () async {
      final g = words(3);
      for (var seed = 0; seed < 1000; seed++) {
        final c = open(g, FakeLearnApi({}), seed: seed);
        final order = (await load(c)).right.map((x) => x.id).join(',');
        expect(order, isNot('r0,r1,r2'), reason: 'seed $seed');
        final again = open(g, FakeLearnApi({}), seed: seed);
        expect((await load(again)).right.map((x) => x.id).join(','), order);
      }
    });

    test('AC-07, AC-11: the card is the definition line, no label, no example', () async {
      final g = [
        w(0, word: 'bank', definition: 'definition: the land along the side of a river\nexample: We sat on the bank.'),
        w(1, word: 'harbour', definition: 'a place where ships stay\nThe harbour was full.'),
        w(2),
        w(3),
      ];
      final api = FakeLearnApi({});
      final s = await load(open(g, api));
      expect(api.calls, isEmpty);
      expect(s.rounds.single.right.firstWhere((x) => x.id == 'r0').text, 'the land along the side of a river');
      expect(s.rounds.single.right.firstWhere((x) => x.id == 'r1').text, 'a place where ships stay');
    });

    test('AC-12: the word is masked in its stored definition', () async {
      final g = [w(0, word: 'walk', definition: 'Walk: to go on foot; she walks and walked home, not by sidewalk'), w(1), w(2), w(3)];
      final s = await load(open(g, FakeLearnApi({})));
      expect(s.rounds.single.right.firstWhere((x) => x.id == 'r0').text,
          '___: to go on foot; she ___ and ___ home, not by sidewalk');
    });
  });

  group('where a definition comes from (S-42)', () {
    test('AC-08, AC-23: only words without a stored line are asked, once, with their translation', () async {
      final g = [w(0, word: ' bank ', translation: ' берег ', definition: ''), w(1), w(2), w(3), w(4, definition: 'example: only')];
      final api = FakeLearnApi({'bank': 'the land along a river', 'word4': 'something else'});
      final c = open(g, api);
      final s = await load(c);
      expect(api.calls.length, 1);
      expect(api.calls.single, [
        (rowId: 'r0', word: 'bank', translation: 'берег'),
        (rowId: 'r4', word: 'word4', translation: 'слово4'),
      ]);
      expect(s.rounds.single.right.firstWhere((x) => x.id == 'r0').text, 'the land along a river');
      expect(g[0].definition, '', reason: 'never written to the word');
      solve(c);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      notifier(c).nextRound();
      expect(api.calls.length, 1, reason: 'no call during rounds or the summary');
    });

    test('AC-10: a word the Worker answers "none" for is left out, with no translation in its place', () async {
      final g = [w(0, word: 'tripod', definition: ''), w(1), w(2), w(3), w(4)];
      final s = await load(open(g, FakeLearnApi({'tripod': null})));
      expect(s.left.map((x) => x.text), ['word1', 'word2', 'word3', 'word4']);
      expect(s.rounds.length, 1);
    });

    test('AC-09: a new open reads the current stored definition', () async {
      final g = words(4);
      final first = await load(open(g, FakeLearnApi({})));
      expect(first.rounds.single.right.firstWhere((x) => x.id == 'r0').text, 'meaning 0');
      final edited = [w(0, definition: 'new text'), ...g.skip(1)];
      final second = await load(open(edited, FakeLearnApi({})));
      expect(second.rounds.single.right.firstWhere((x) => x.id == 'r0').text, 'new text');
    });
  });

  group('fair cards', () {
    test('AC-13: a definition that is only the word leaves the word out', () async {
      final g = [w(0, word: 'echo', definition: 'Echo.'), w(1), w(2), w(3)];
      final s = await load(open(g, FakeLearnApi({})));
      expect(s.left.map((x) => x.id), ['r1', 'r2', 'r3']);
    });

    test('AC-14: a long definition is cut for the card', () async {
      final long = List.filled(60, 'word').join(' ');
      final g = [w(0, definition: long), w(1), w(2), w(3)];
      final s = await load(open(g, FakeLearnApi({})));
      final text = s.rounds.single.right.firstWhere((x) => x.id == 'r0').text;
      expect(text.endsWith('…'), isTrue);
      expect(text.length, lessThanOrEqualTo(121));
    });

    test('AC-15: equal cards and equal words: the earlier word stays', () async {
      final g = [
        w(0, word: 'big', definition: 'Large in size, extent and amount'),
        w(1, word: 'huge', definition: 'large  in size, extent and amount'),
        w(2, word: 'bank', translation: 'банк', definition: 'a place for money'),
        w(3, word: 'bank', translation: 'берег', definition: 'the side of a river'),
        w(4),
      ];
      final s = await load(open(g, FakeLearnApi({})));
      expect(s.left.map((x) => x.id), ['r0', 'r2', 'r4']);
    });

    test('AC-15: two definitions that read the same only after the cut keep the first', () async {
      final base = List.filled(30, 'same').join(' ');
      final g = [w(0, definition: '$base alpha beta'), w(1, definition: '$base gamma delta'), w(2), w(3)];
      final s = await load(open(g, FakeLearnApi({})));
      expect(s.left.map((x) => x.id), ['r0', 'r2', 'r3']);
    });

    test('§6 fairness: no unmasked word, equal cards or second right card over 1000 seeds', () async {
      final g = [
        w(0, word: 'walk', definition: 'to walk on foot'), w(1, word: 'big', definition: 'large'),
        w(2, word: 'huge', definition: 'LARGE'), w(3, word: 'bank', definition: 'a bank of a river'),
        w(4, word: 'bank', definition: 'a place for money'), w(5, word: 'echo', definition: 'echo'),
        w(6, word: 'give up', definition: 'to give up means to stop'), w(7), w(8), w(9),
      ];
      String norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      for (var seed = 0; seed < 1000; seed++) {
        final s = await load(open(g, FakeLearnApi({}), seed: seed));
        for (final r in s.rounds) {
          final cards = [...r.left.map((x) => norm(x.text)), ...r.right.map((x) => norm(x.text))];
          expect(cards.toSet().length, cards.length, reason: 'seed $seed: $cards');
          for (final p in r.pairs) {
            expect(r.right.where((x) => x.id == p.rowId).length, 1);
            expect(r.right.firstWhere((x) => x.id == p.rowId).text.toLowerCase().contains(p.word.toLowerCase()), isFalse);
          }
        }
      }
    });
  });

  group('rounds, empty and error states', () {
    test('AC-16: 8 → 4+4, 7 → 4+3, 13 → 5+4+4, 6 → 6', () async {
      for (final (n, sizes) in [(8, [4, 4]), (7, [4, 3]), (13, [5, 4, 4]), (6, [6])]) {
        final s = await load(open(words(n), FakeLearnApi({})));
        expect(s.rounds.map((r) => r.left.length), sizes, reason: '$n words');
        expect((s.phase as ExerciseRound).count, sizes.length);
      }
    });

    test('AC-17: fewer than 3 usable after the definitions shows the definition line', () async {
      final g = [w(0, definition: ''), w(1, definition: ''), w(2), w(3, definition: 'example: x')];
      final s = await load(open(g, FakeLearnApi({'word0': 'a', 'word1': null, 'word3': null})));
      expect((s.phase as ExerciseNotEnough).message, 'Not enough words with definitions for this group');
    });

    test('AC-18: fewer than 3 words to learn shows the default line and asks nobody', () async {
      for (final n in [0, 2]) {
        final api = FakeLearnApi({});
        final g = [for (var i = 0; i < n; i++) w(i, definition: '')];
        final s = await load(open(g, api));
        expect((s.phase as ExerciseNotEnough).message, isNull);
        expect(api.calls, isEmpty);
      }
    });

    test('AC-19: a failed needed call is an error even with stored definitions; Retry asks again', () async {
      final g = [w(0, definition: ''), w(1), w(2), w(3)];
      final api = FakeLearnApi({'word0': 'a thing'}, error: LearnApiException(LearnApiError.network, 'offline'));
      final c = open(g, api);
      await expectLater(load(c), throwsA(isA<LearnApiException>()));
      expect(failureOf(c.read(provider).error!), ExerciseFailure.network);
      api.error = null;
      notifier(c).retry();
      expect((await load(c)).phase, isA<ExerciseRound>());
      expect(api.calls.length, 2);
    });
  });

  group('pairing and the summary', () {
    test('AC-03, AC-04: a right pair links, a wrong one counts a miss on the word', () async {
      final c = open(words(4), FakeLearnApi({}));
      await load(c);
      expect(notifier(c).pair('r2', 'r2'), isTrue);
      expect(notifier(c).pair('r0', 'r1'), isFalse);
      expect(notifier(c).pair('r0', 'r3'), isFalse);
      expect(now(c).links.keys, ['r2']);
      expect(now(c).misses, {'r0': 2});
    });

    test('AC-05, AC-21: the summary opens about 500 ms after the last link, misses in group order', () async {
      final c = open(words(8), FakeLearnApi({}));
      await load(c);
      notifier(c).pair('r0', 'r1');
      notifier(c).pair('r0', 'r2');
      notifier(c).pair('r1', 'r3');
      solve(c);
      expect(now(c).phase, isA<ExerciseRound>());
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final summary = now(c).phase as ExerciseSummary;
      expect(summary.hasNextRound, isTrue);
      expect(summary.outcomes.map((o) => (o.word, o.result)),
          [('word0', '2 misses'), ('word1', '1 miss'), ('word2', 'no misses'), ('word3', 'no misses')]);
      notifier(c).nextRound();
      expect((now(c).phase as ExerciseRound).index, 1);
      expect(now(c).links, isEmpty);
      expect(now(c).misses, isEmpty);
    });
  });
}
