import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/learn/session/ladder_queue.dart';

/// learn-redesign T5: the pure ladder queue (ADR-0004; AC-08, AC-09, AC-14's
/// "within the session due words get their pages first").
void main() {
  LadderQueue queue(List<String> ids,
          {Set<String> due = const {}, int seed = 1}) =>
      LadderQueue(ids, due: due, random: Random(seed));

  /// Plays the queue answering everything right; returns the shown order.
  List<({String rowId, Rung rung})> playAllRight(LadderQueue q) {
    final shown = <({String rowId, Rung rung})>[];
    for (var guard = 0; guard < 1000; guard++) {
      final page = q.next();
      if (page == null) break;
      shown.add(page);
      q.record(page.rowId, true);
    }
    return shown;
  }

  test('rungs are steps 1, 2 and 3', () {
    expect(Rung.meet.step, 1);
    expect(Rung.practise.step, 2);
    expect(Rung.use.step, 3);
  });

  test('a clean word takes exactly 3 rights: Meet, Practise, Use, then passed',
      () {
    final q = queue(['a']);
    expect(q.rungOf('a'), Rung.meet);
    expect(q.next(), (rowId: 'a', rung: Rung.meet));
    q.record('a', true);
    expect(q.rungOf('a'), Rung.practise);
    expect(q.next(), (rowId: 'a', rung: Rung.practise));
    q.record('a', true);
    expect(q.rungOf('a'), Rung.use);
    expect(q.passed('a'), isFalse);
    expect(q.next(), (rowId: 'a', rung: Rung.use));
    q.record('a', true);
    expect(q.passed('a'), isTrue);
    expect(q.isDone, isTrue);
    expect(q.next(), isNull);
    expect(q.answered, 3);
    expect(q.missed('a'), isFalse);
  });

  test('every word meets step 1, then 2, then 3, and all right = 3 pages each',
      () {
    final q = queue(['a', 'b', 'c', 'd', 'e']);
    final shown = playAllRight(q);
    expect(shown, hasLength(15));
    for (final id in ['a', 'b', 'c', 'd', 'e']) {
      final rungs = [
        for (final p in shown)
          if (p.rowId == id) p.rung
      ];
      expect(rungs, [Rung.meet, Rung.practise, Rung.use], reason: id);
      expect(q.passed(id), isTrue);
    }
    expect(q.isDone, isTrue);
  });

  test('a miss on Practise moves the word to Meet and it returns 3 pages later',
      () {
    final q = queue(['a', 'b', 'c', 'd', 'e']);
    // Round one: every word right on Meet.
    for (var i = 0; i < 5; i++) {
      final p = q.next()!;
      q.record(p.rowId, true);
    }
    final missedPage = q.next()!;
    expect(missedPage.rung, Rung.practise);
    q.record(missedPage.rowId, false);
    expect(q.rungOf(missedPage.rowId), Rung.meet);
    expect(q.missed(missedPage.rowId), isTrue);

    final later = <({String rowId, Rung rung})>[];
    for (var i = 0; i < 3; i++) {
      final p = q.next()!;
      later.add(p);
      q.record(p.rowId, true);
    }
    expect(later[0].rowId, isNot(missedPage.rowId));
    expect(later[1].rowId, isNot(missedPage.rowId));
    expect(later[2], (rowId: missedPage.rowId, rung: Rung.meet));
  });

  test('a missed word goes to the end when fewer than 3 pages remain', () {
    final q = queue(['a', 'b']);
    final first = q.next()!;
    q.record(first.rowId, false);
    final second = q.next()!;
    expect(second.rowId, isNot(first.rowId));
    q.record(second.rowId, true);
    // Pending was [second] when first was missed, so first went to the end,
    // before second's re-entry: first comes next.
    expect(q.next(), (rowId: first.rowId, rung: Rung.meet));
  });

  test('the reinsert distance can be injected', () {
    final q = LadderQueue(['a', 'b', 'c', 'd', 'e'],
        random: Random(3), reinsertDistance: 2);
    final missed = q.next()!;
    q.record(missed.rowId, false);
    final one = q.next()!;
    q.record(one.rowId, true);
    expect(q.next()!.rowId, missed.rowId);
    expect(LadderQueue.defaultReinsertDistance, 3);
  });

  test('a miss on Meet keeps the word on Meet and sets its miss flag', () {
    final q = queue(['a', 'b', 'c']);
    final p = q.next()!;
    expect(p.rung, Rung.meet);
    q.record(p.rowId, false);
    expect(q.rungOf(p.rowId), Rung.meet);
    expect(q.missed(p.rowId), isTrue);
    for (final id in ['a', 'b', 'c'].where((id) => id != p.rowId)) {
      expect(q.missed(id), isFalse);
    }
  });

  test('a miss on Use drops to Practise; the flag stays after passing', () {
    final q = queue(['a']);
    q.record('a', true);
    q.record('a', true);
    expect(q.rungOf('a'), Rung.use);
    q.record('a', false);
    expect(q.rungOf('a'), Rung.practise);
    q.record('a', true);
    q.record('a', true);
    expect(q.passed('a'), isTrue);
    expect(q.missed('a'), isTrue);
    expect(q.answered, 5);
  });

  test('the same word is never next twice in a row while another is pending',
      () {
    for (var seed = 0; seed < 30; seed++) {
      final random = Random(seed + 100);
      final q = LadderQueue(['a', 'b', 'c', 'd'],
          random: Random(seed), reinsertDistance: 1 + seed % 3);
      String? last;
      for (var guard = 0; guard < 500; guard++) {
        final p = q.next();
        if (p == null) break;
        if (last != null && p.rowId == last) {
          // Only allowed when this word is the last one pending.
          expect(q.pendingCount, 1, reason: 'seed $seed');
        }
        last = p.rowId;
        q.record(p.rowId, random.nextInt(3) != 0);
      }
      expect(q.isDone, isTrue, reason: 'seed $seed');
    }
  });

  test('due words come first, each class shuffled by the given Random', () {
    final ids = [for (var i = 0; i < 10; i++) 'w$i'];
    const due = {'w7', 'w2', 'w9'};
    final orders = <List<String>>{};
    for (var seed = 0; seed < 10; seed++) {
      final q = queue(ids, due: due, seed: seed);
      final firstRound = [
        for (final p in playAllRight(q).take(10)) p.rowId,
      ];
      expect(firstRound.take(3).toSet(), due, reason: 'seed $seed');
      expect(firstRound.toSet(), ids.toSet());
      orders.add(firstRound);
    }
    expect(orders.length, greaterThan(1), reason: 'order is shuffled');
    // Same seed, same order.
    expect(playAllRight(queue(ids, due: due, seed: 4)),
        playAllRight(queue(ids, due: due, seed: 4)));
  });

  test('isDone only when every word has passed a Use page', () {
    final q = queue(['a', 'b']);
    expect(q.isDone, isFalse);
    q.record('a', true);
    q.record('a', true);
    q.record('a', true);
    expect(q.passed('a'), isTrue);
    expect(q.isDone, isFalse);
    expect(q.next(), (rowId: 'b', rung: Rung.meet));
    q.record('b', true);
    q.record('b', true);
    q.record('b', true);
    expect(q.isDone, isTrue);
    expect(q.next(), isNull);
  });

  test('an empty queue is done at once', () {
    final q = queue([]);
    expect(q.isDone, isTrue);
    expect(q.next(), isNull);
    expect(q.estimatedTotal, 0);
  });

  test('estimatedTotal = answered + remaining rungs of every pending word', () {
    final q = queue(['a', 'b', 'c']);
    expect(q.estimatedTotal, 9);
    q.record('a', true); // a: practise (2 left)
    expect(q.answered, 1);
    expect(q.estimatedTotal, 1 + 2 + 3 + 3);
    q.record('a', false); // a: back to meet (3 left)
    expect(q.estimatedTotal, 2 + 3 + 3 + 3);
    q.record('b', true);
    q.record('b', true);
    q.record('b', true); // b passed
    expect(q.estimatedTotal, 5 + 3 + 3);
  });

  test('recording a passed or unknown word is an error', () {
    final q = queue(['a']);
    expect(() => q.record('x', true), throwsArgumentError);
    q.record('a', true);
    q.record('a', true);
    q.record('a', true);
    expect(() => q.record('a', true), throwsStateError);
  });
}
