import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/learn/session/check_queue.dart';
import 'package:flutter_vocabulary_app/features/learn/session/ladder_queue.dart';

/// self-check-cards T5 (AC-02): the pure scheduling of self-check cards.
void main() {
  const mistake = CheckReason.mistake;
  const hint = CheckReason.hint;

  test('a card is due 3 pages of other words after its flag', () {
    final q = CheckQueue<int>();
    q.pageDone(['a'], {'a': mistake});
    expect(q.due(next: 'b'), isNull);
    q.pageDone(['b']);
    q.pageDone(['c']);
    expect(q.due(next: 'd'), isNull);
    q.pageDone(['d']);
    expect(q.due(next: 'e')?.rowId, 'a');
    expect(q.due(next: 'e')?.reason, mistake);
  });

  test("the word's own pages do not count towards the 3", () {
    final q = CheckQueue<int>();
    q.pageDone(['a'], {'a': hint});
    q.pageDone(['b']);
    q.pageDone(['a']);
    q.pageDone(['c']);
    expect(q.due(next: 'e'), isNull);
    q.pageDone(['d']);
    expect(q.due(next: 'e')?.rowId, 'a');
  });

  test('fewer pages left: the card comes right after the last exercise page', () {
    final q = CheckQueue<int>();
    q.pageDone(['a'], {'a': mistake});
    q.pageDone(['b']);
    expect(q.due(next: null)?.rowId, 'a');
  });

  test("never next to the same word's own page while another page is pending", () {
    final q = CheckQueue<int>();
    q.pageDone(['a'], {'a': mistake});
    q.pageDone(['b']);
    q.pageDone(['c']);
    q.pageDone(['d']);
    // The next page is a's own: the card waits.
    expect(q.due(next: 'a'), isNull);
    // ... unless a's is the only page left.
    expect(q.due(next: 'a', othersPending: (_) => false)?.rowId, 'a');
    q.pageDone(['a']);
    // Just after a's own page: still waits.
    expect(q.due(next: 'e'), isNull);
    q.pageDone(['e']);
    expect(q.due(next: 'f')?.rowId, 'a');
  });

  test('every flag gets a card, no limit, in flag order', () {
    final q = CheckQueue<int>();
    final ids = [for (var i = 0; i < 12; i++) 'w$i'];
    for (final id in ids) {
      q.pageDone([id], {id: mistake});
    }
    expect(q.waitingCount, 12);
    final shown = <String>[];
    for (var card = q.due(next: 'x'); card != null; card = q.due(next: 'x')) {
      shown.add(card.rowId);
      q.rate(card.rowId, 1);
    }
    // w9..w11 have fewer than 3 other pages after their flag.
    expect(shown, ids.take(9));
    for (var card = q.due(next: null); card != null; card = q.due(next: null)) {
      shown.add(card.rowId);
      q.rate(card.rowId, 1);
    }
    expect(shown, ids);
    expect(q.rated, 12);
  });

  test('flagged again while its card waits: one card, a mistake wins over a hint', () {
    final q = CheckQueue<int>();
    q.pageDone(['a'], {'a': hint});
    q.pageDone(['a'], {'a': mistake});
    expect(q.waitingCount, 1);
    expect(q.due(next: null)?.reason, mistake);
  });

  test('flagged again after its card: a new card, and the last rating counts', () {
    final q = CheckQueue<String>();
    q.pageDone(['a'], {'a': mistake});
    q.rate('a', 'hard');
    expect(q.isWaiting('a'), isFalse);
    q.pageDone(['a'], {'a': hint});
    expect(q.isWaiting('a'), isTrue);
    for (final id in ['b', 'c', 'd']) {
      q.pageDone([id]);
    }
    expect(q.due(next: 'e')?.rowId, 'a');
    q.rate('a', 'easy');
    expect(q.ratings, {'a': 'easy'});
    expect(q.ratedReasons, {'a': hint});
    expect(q.rated, 2);
    expect(() => q.rate('a', 'easy'), throwsStateError);
  });

  test('a played session (seeded Random): every rule holds', () {
    for (var seed = 0; seed < 40; seed++) {
      final random = Random(seed);
      final ids = [for (var i = 0; i < 2 + seed % 9; i++) 'w$i'];
      final ladder = LadderQueue(ids, random: random);
      final checks = CheckQueue<int>();
      // ('page' | 'card', rowId), in the order shown.
      final shown = <(String, String)>[];
      final flags = <(int, String)>[];
      final lastRating = <String, int>{};
      while (true) {
        final next = ladder.next();
        final card = checks.due(
          next: next?.rowId,
          othersPending: (id) => ladder.pendingCount > (ladder.passed(id) ? 0 : 1),
        );
        if (card != null) {
          shown.add(('card', card.rowId));
          final rating = random.nextInt(4);
          lastRating[card.rowId] = rating;
          checks.rate(card.rowId, rating);
          continue;
        }
        if (next == null) break;
        final outcome = random.nextInt(5); // 0 wrong, 1 hinted, else right
        shown.add(('page', next.rowId));
        ladder.record(next.rowId, outcome != 0);
        final flag = switch (outcome) { 0 => mistake, 1 => hint, _ => null };
        if (flag != null) flags.add((shown.length - 1, next.rowId));
        checks.pageDone([next.rowId], {if (flag != null) next.rowId: flag});
      }

      expect(checks.waitingCount, 0, reason: 'seed $seed');
      expect(checks.ratings, lastRating, reason: 'seed $seed');
      final cards = [for (var i = 0; i < shown.length; i++) if (shown[i].$1 == 'card') i];
      expect(cards.length, checks.rated, reason: 'seed $seed');

      bool otherPageAfter(int i, String id) =>
          shown.skip(i + 1).any((e) => e.$1 == 'page' && e.$2 != id);
      for (final i in cards) {
        final id = shown[i].$2;
        // Not directly next to its own page while another word's page is pending.
        if (i > 0 && shown[i - 1] == ('page', id)) {
          expect(otherPageAfter(i, id), isFalse, reason: 'seed $seed: card $i after own page');
        }
        if (i + 1 < shown.length && shown[i + 1] == ('page', id)) {
          expect(otherPageAfter(i, id), isFalse, reason: 'seed $seed: card $i before own page');
        }
      }
      // Every flag has a card after it; a flag that opened a card has 3
      // other-word pages before it unless no exercise page follows the card.
      for (final (f, id) in flags) {
        final i = cards.firstWhere((c) => c > f && shown[c].$2 == id,
            orElse: () => fail('seed $seed: flag at $f has no card'));
        final merged = flags.any((g) =>
            g.$2 == id && g.$1 < f && !cards.any((c) => c > g.$1 && c < f && shown[c].$2 == id));
        if (merged) continue;
        final others = shown.sublist(f + 1, i).where((e) => e.$1 == 'page' && e.$2 != id).length;
        final tail = !shown.skip(i + 1).any((e) => e.$1 == 'page');
        expect(others >= 3 || tail, isTrue, reason: 'seed $seed: card at $i after $others pages');
      }
    }
  });
}
