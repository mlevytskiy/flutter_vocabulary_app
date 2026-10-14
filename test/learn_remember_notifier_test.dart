import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/remember_or_not/remember_or_not_notifier.dart';

/// learn-remember-or-not: usable words, fronts, rounds, shuffle, rating, repeat
/// and the summary (AC-02 – AC-04, AC-10 – AC-14, AC-16; S-34).
void main() {
  WordPair w(int i, {String definition = '', String? word, String? translation}) => WordPair(
        word: word ?? 'word$i',
        translation: translation ?? 'слово$i',
        definition: definition,
        rowId: 'r$i',
      );

  List<WordPair> words(int n) => [for (var i = 0; i < n; i++) w(i)];

  ProviderContainer open(List<WordPair> g,
      {int seed = 1, Object? error, List<FilmDialogue> dialogues = const []}) {
    final c = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(seed)),
      exerciseWordsProvider(null, 'g').overrideWith((ref) async {
        if (error != null) throw error;
        return (group: g, others: const <WordPair>[]);
      }),
      exerciseDialoguesProvider(null).overrideWith((ref) async => dialogues),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<RememberState> load(ProviderContainer c) => c.read(rememberOrNotProvider(null, 'g').future);
  RememberOrNot notifier(ProviderContainer c) => c.read(rememberOrNotProvider(null, 'g').notifier);
  RememberState now(ProviderContainer c) => c.read(rememberOrNotProvider(null, 'g')).requireValue;

  void rate(ProviderContainer c, bool ok) {
    notifier(c).flip();
    notifier(c).rate(ok);
  }

  group('fronts and usable words', () {
    test('AC-02: masked definition; translation (masked) without one', () async {
      final c = open([
        w(0, word: 'cat', definition: 'A cat is a small animal'),
        w(1, word: 'dog', translation: 'a dog (пес)'),
        w(2),
      ]);
      final s = await load(c);
      final fronts = {for (final card in s.cards) card.word: card.front};
      expect(fronts['cat'], 'A ___ is a small animal');
      expect(fronts['dog'], 'a ___ (пес)');
      expect(fronts['word2'], 'слово2');
    });

    test('AC-03: a definition that is only the word falls back to the translation; no letter at all is unusable', () async {
      final c = open([
        w(0, word: 'cat', definition: 'Cat', translation: 'кіт'),
        w(1, word: 'dog', translation: 'dog'),
        w(2),
        w(3),
        w(4),
      ]);
      final s = await load(c);
      expect(s.cards.map((x) => x.word), unorderedEquals(['cat', 'word2', 'word3', 'word4']));
      expect(s.cards.firstWhere((x) => x.word == 'cat').front, 'кіт');
      final all = <String>[];
      while (now(c).card != null) {
        all.add(now(c).card!.word);
        rate(c, true);
      }
      expect(all, isNot(contains('dog')));
      expect((now(c).phase as ExerciseSummary).outcomes.map((o) => o.word), isNot(contains('dog')));
    });

    test('AC-16: fewer than 3 usable words is not enough', () async {
      final c = open([w(0), w(1), w(2, word: 'x', translation: 'x')]);
      expect((await load(c)).phase, isA<ExerciseNotEnough>());
      expect((await load(open(const []))).phase, isA<ExerciseNotEnough>());
    });

    test('AC-06: the example line comes from a linked dialogue', () async {
      final d = FilmDialogue()
        ..id = 'd'
        ..lines = ['Say word1 once.']
        ..wordRowIds = ['r1'];
      final s = await load(open(words(3), dialogues: [d]));
      expect(s.cards.firstWhere((x) => x.rowId == 'r1').example, 'Say word1 once.');
      expect(s.cards.firstWhere((x) => x.rowId == 'r0').example, isNull);
    });
  });

  group('rounds and shuffle (AC-04, S-34)', () {
    test('13 words: 7 + 6 in group order, shuffled inside; same seed same order', () async {
      final s = await load(open(words(13), seed: 5));
      expect(s.rounds.map((r) => r.length), [7, 6]);
      expect(s.rounds[0].map((x) => x.rowId), unorderedEquals([for (var i = 0; i < 7; i++) 'r$i']));
      expect(s.rounds[1].map((x) => x.rowId), unorderedEquals([for (var i = 7; i < 13; i++) 'r$i']));
      expect(s.rounds[0].map((x) => x.rowId).toList(), isNot([for (var i = 0; i < 7; i++) 'r$i']));
      final again = await load(open(words(13), seed: 5));
      expect(again.rounds[0].map((x) => x.rowId), s.rounds[0].map((x) => x.rowId));
      final other = await load(open(words(13), seed: 6));
      expect(other.rounds[0].map((x) => x.rowId).toList(), isNot(s.rounds[0].map((x) => x.rowId).toList()));
    });

    test('9 give one round of 9, 10 give 5 + 5', () async {
      expect((await load(open(words(9)))).rounds.map((r) => r.length), [9]);
      expect((await load(open(words(10)))).rounds.map((r) => r.length), [5, 5]);
    });
  });

  group('rating and repeat', () {
    test('AC-01/AC-05: starts at card 1 of n on the front; flip once; rate needs a flip', () async {
      final c = open(words(5));
      var s = await load(c);
      expect(s.position, 1);
      expect(s.total, 5);
      expect(s.flipped, isFalse);
      notifier(c).rate(true);
      expect(now(c).position, 1, reason: 'rating before the flip does nothing');
      notifier(c).flip();
      expect(now(c).flipped, isTrue);
    });

    test('AC-10: Remembered moves on; the last card opens the summary', () async {
      final c = open(words(3));
      await load(c);
      rate(c, true);
      expect(now(c).position, 2);
      expect(now(c).flipped, isFalse);
      rate(c, true);
      rate(c, true);
      expect(now(c).phase, isA<ExerciseSummary>());
    });

    test('AC-11: Not yet puts the card at the end, counter grows, second showing', () async {
      final c = open(words(5));
      await load(c);
      rate(c, true);
      final missed = now(c).card!.rowId;
      rate(c, false);
      expect(now(c).position, 3);
      expect(now(c).total, 6);
      for (var i = 0; i < 3; i++) {
        expect(now(c).secondShowing, isFalse);
        rate(c, true);
      }
      expect(now(c).card!.rowId, missed);
      expect(now(c).secondShowing, isTrue);
      expect(now(c).flipped, isFalse);
      expect(now(c).position, 6);
    });

    test('AC-12: second showing ends the card: Got it / Still not', () async {
      final c = open(words(3));
      await load(c);
      final order = now(c).cards.map((x) => x.rowId).toList();
      rate(c, false);
      rate(c, false);
      rate(c, true);
      expect(now(c).secondShowing, isTrue);
      rate(c, true); // order[0] again: Got it
      expect(now(c).secondShowing, isTrue);
      rate(c, false); // order[1] again: Still not
      final sum = now(c).phase as ExerciseSummary;
      expect(sum.outcomes.map((o) => o.rowId), order);
      expect(sum.outcomes.map((o) => o.result), ['Remembered after repeat', 'Not yet', 'Remembered']);
      expect(sum.heading, '1 remembered, 1 after repeat, 1 not yet');
    });

    test('AC-13: the last card put back shows again at once', () async {
      final c = open(words(3));
      await load(c);
      rate(c, true);
      rate(c, true);
      final last = now(c).card!.rowId;
      rate(c, false);
      expect(now(c).card!.rowId, last);
      expect(now(c).secondShowing, isTrue);
      expect(now(c).flipped, isFalse);
    });

    test('AC-14: heading counts and next round', () async {
      final c = open(words(13));
      await load(c);
      while (now(c).phase is ExerciseRound) {
        rate(c, true);
      }
      var sum = now(c).phase as ExerciseSummary;
      expect(sum.heading, '7 remembered, 0 after repeat, 0 not yet');
      expect(sum.hasNextRound, isTrue);
      notifier(c).nextRound();
      expect(now(c).position, 1);
      expect(now(c).total, 6);
      while (now(c).phase is ExerciseRound) {
        rate(c, true);
      }
      sum = now(c).phase as ExerciseSummary;
      expect(sum.hasNextRound, isFalse);
      expect(sum.outcomes.length, 6);
    });

    test('every rating sequence of a 3-card round ends in at most 6 showings', () async {
      for (var mask = 0; mask < 64; mask++) {
        final c = open(words(3));
        await load(c);
        var showings = 0;
        while (now(c).phase is ExerciseRound) {
          rate(c, (mask >> showings) & 1 == 1);
          showings++;
          expect(showings, lessThanOrEqualTo(6));
        }
        expect(now(c).results.length, 3);
      }
    });

    test('random sequences of a 9-card round end in at most 18 showings', () async {
      final r = Random(2);
      for (var k = 0; k < 50; k++) {
        final c = open(words(9), seed: k);
        await load(c);
        var showings = 0;
        while (now(c).phase is ExerciseRound) {
          rate(c, r.nextBool());
          showings++;
        }
        expect(showings, lessThanOrEqualTo(18));
      }
    });
  });

  test('AC-17: a load error is an error state, Retry loads again', () async {
    var fail = true;
    final c = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(1)),
      exerciseWordsProvider(null, 'g').overrideWith((ref) async {
        if (fail) throw StateError('x');
        return (group: words(3), others: const <WordPair>[]);
      }),
      exerciseDialoguesProvider(null).overrideWith((ref) async => const <FilmDialogue>[]),
    ]);
    addTearDown(c.dispose);
    await expectLater(load(c), throwsStateError);
    fail = false;
    notifier(c).retry();
    expect((await load(c)).cards.length, 3);
  });
}
