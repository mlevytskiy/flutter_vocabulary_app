import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/session/leitner.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';

/// learn-redesign T3: the pure Leitner rules (AC-12, AC-13, AC-15, AC-22).
void main() {
  final now = DateTime(2026, 10, 23, 15, 30);
  final today = DateTime(2026, 10, 23);
  const todayKey = '2026-10-23';

  WordPair row(String id, String word) => WordPair(word: word, rowId: id);

  WordBox box(String id, String word, int n,
          {DateTime? dueAt, String lastUpDay = ''}) =>
      WordBox()
        ..rowId = id
        ..word = word
        ..box = n
        ..dueAt = dueAt ?? today
        ..lastUpDay = lastUpDay;

  group('boxKey / boxOf', () {
    test('boxKey trims and lower-cases', () {
      expect(boxKey('  Apple '), 'apple');
    });

    test('boxOf matches by row id and normalised word', () {
      final b = box('r1', 'apple', 3);
      expect(boxOf([b], row('r1', ' Apple')), same(b));
    });

    test('boxOf returns null for another row or a changed word', () {
      final b = box('r1', 'apple', 3);
      expect(boxOf([b], row('r2', 'apple')), isNull);
      expect(boxOf([b], row('r1', 'pear')), isNull);
    });
  });

  group('isDue', () {
    test('a new word (no box) is not due', () {
      expect(isDue(null, now), isFalse);
    });

    test('due when dueAt falls on today or earlier, by calendar day', () {
      expect(isDue(box('r', 'a', 1, dueAt: DateTime(2026, 10, 23, 23, 59)), now),
          isTrue);
      expect(isDue(box('r', 'a', 1, dueAt: DateTime(2026, 10, 20)), now), isTrue);
      expect(isDue(box('r', 'a', 1, dueAt: DateTime(2026, 10, 24)), now), isFalse);
    });
  });

  test('intervalDays is 1, 2, 4, 8, 16 for box 1 to 5', () {
    expect([1, 2, 3, 4, 5].map(intervalDays), [1, 2, 4, 8, 16]);
  });

  group('applySession (AC-13)', () {
    test('a new clean word goes to box 1, due tomorrow, known well', () {
      final r = row('r1', 'Apple');
      final result = applySession([], {r: WordOutcome.clean}, now);
      expect(result.boxes, hasLength(1));
      final b = result.boxes.single;
      expect(b.rowId, 'r1');
      expect(b.word, 'apple');
      expect(b.box, 1);
      expect(b.dueAt, DateTime(2026, 10, 24));
      expect(b.lastUpDay, todayKey);
      final m = result.moves.single;
      expect(m.state, WordState.knownWell);
      expect(m.before, isNull);
      expect(m.after!.box, 1);
    });

    test('a clean word moves up one box with its interval', () {
      final r = row('r1', 'apple');
      final result = applySession(
          [box('r1', 'apple', 2, lastUpDay: '2026-10-20')],
          {r: WordOutcome.clean},
          now);
      expect(result.boxes.single.box, 3);
      expect(result.boxes.single.dueAt, DateTime(2026, 10, 27));
    });

    test('box 5 stays 5, due in 16 days', () {
      final r = row('r1', 'apple');
      final result = applySession(
          [box('r1', 'apple', 5, lastUpDay: '2026-10-01')],
          {r: WordOutcome.clean},
          now);
      expect(result.boxes.single.box, 5);
      expect(result.boxes.single.dueAt, DateTime(2026, 11, 8));
      expect(result.moves.single.state, WordState.knownWell);
    });

    test('a second clean session the same day does not move up again', () {
      final r = row('r1', 'apple');
      final first = applySession([], {r: WordOutcome.clean}, now);
      final second = applySession(
          first.boxes, {r: WordOutcome.clean}, now.add(const Duration(hours: 1)));
      expect(second.boxes.single.box, 1);
      expect(second.boxes.single.dueAt, DateTime(2026, 10, 24));
      expect(second.moves.single.state, WordState.knownWell);
    });

    test('a miss without a rating keeps box and next review (self-check-cards AC-01, AC-09)', () {
      final r = row('r1', 'apple');
      final due = DateTime(2026, 10, 30);
      final result = applySession(
          [box('r1', 'apple', 4, dueAt: due, lastUpDay: todayKey)],
          {r: WordOutcome.missed},
          now);
      expect(result.boxes.single.box, 4);
      expect(result.boxes.single.dueAt, due);
      expect(result.boxes.single.lastUpDay, todayKey);
      final m = result.moves.single;
      expect(m.state, WordState.shaky);
      expect(m.rating, isNull);
      expect(m.after!.box, 4);
      expect(m.after!.dueAt, due);
    });

    test('a hinted word without a rating keeps its box too (AC-09)', () {
      final r = row('r1', 'apple');
      final result =
          applySession([box('r1', 'apple', 3)], {r: WordOutcome.hinted}, now);
      expect(result.boxes.single.box, 3);
      expect(result.boxes.single.dueAt, today);
      expect(result.moves.single.state, WordState.shaky);
    });

    test('a miss on a new word without a rating gives no box and state new', () {
      final r = row('r1', 'apple');
      final result = applySession([], {r: WordOutcome.missed}, now);
      expect(result.boxes, isEmpty);
      expect(result.moves.single.state, WordState.isNew);
      expect(result.moves.single.before, isNull);
      expect(result.moves.single.after, isNull);
    });

    test('an unused word keeps its box and next review (AC-22)', () {
      final r = row('r1', 'apple');
      final due = DateTime(2026, 10, 30);
      final result = applySession(
          [box('r1', 'apple', 3, dueAt: due, lastUpDay: '2026-10-22')],
          {r: WordOutcome.unused},
          now);
      final b = result.boxes.single;
      expect(b.box, 3);
      expect(b.dueAt, due);
      expect(b.lastUpDay, '2026-10-22');
      expect(result.moves.single.state, WordState.unused);
    });

    test('an unused new word gets no box', () {
      final result =
          applySession([], {row('r1', 'apple'): WordOutcome.unused}, now);
      expect(result.boxes, isEmpty);
      expect(result.moves.single.state, WordState.unused);
      expect(result.moves.single.after, isNull);
    });

    test('an edited English word starts again as new (AC-15)', () {
      final r = row('r1', 'pear');
      final result = applySession(
          [box('r1', 'apple', 4, lastUpDay: '2026-10-01')],
          {r: WordOutcome.missed},
          now,
          ratings: {r: (rating: SelfRating.hard, side: 'uk')});
      expect(result.boxes, hasLength(1));
      expect(result.boxes.single.word, 'pear');
      expect(result.boxes.single.box, 1);
      expect(result.moves.single.state, WordState.isNew);
      expect(result.moves.single.before, isNull);
    });

    test('an edited word that is clean goes to box 1, not up from the old box',
        () {
      final r = row('r1', 'pear');
      final result = applySession(
          [box('r1', 'apple', 4, lastUpDay: todayKey)],
          {r: WordOutcome.clean},
          now);
      expect(result.boxes.single.box, 1);
      expect(result.boxes.single.word, 'pear');
    });

    test('boxes of rows that are gone are pruned (AC-15)', () {
      final result = applySession(
        [box('r1', 'apple', 2), box('gone', 'pear', 3)],
        {row('r1', 'apple'): WordOutcome.clean},
        now,
        liveRowIds: {'r1'},
      );
      expect(result.boxes.map((b) => b.rowId), ['r1']);
    });

    test('boxes not in the session are kept as they are', () {
      final other = box('r2', 'pear', 3, dueAt: DateTime(2026, 11, 1));
      final result = applySession(
          [other], {row('r1', 'apple'): WordOutcome.clean}, now);
      expect(result.boxes, hasLength(2));
      final kept = result.boxes.firstWhere((b) => b.rowId == 'r2');
      expect(kept.box, 3);
      expect(kept.dueAt, DateTime(2026, 11, 1));
    });

    test('inputs are not mutated', () {
      final original = box('r1', 'apple', 2, lastUpDay: '2026-10-20');
      final boxes = [original];
      final r = row('r1', 'apple');
      final result = applySession(boxes, {r: WordOutcome.clean}, now);
      expect(boxes, hasLength(1));
      expect(original.box, 2);
      expect(original.lastUpDay, '2026-10-20');
      expect(original.dueAt, today);
      expect(r.word, 'apple');
      expect(result.boxes.single, isNot(same(original)));
      expect(result.moves.single.before, isNot(same(original)));
      expect(result.moves.single.before!.box, 2);
    });

    test('a move carries row id, word, before and after', () {
      final result = applySession(
          [box('r1', 'apple', 2, lastUpDay: '2026-10-20')],
          {row('r1', 'Apple'): WordOutcome.clean},
          now);
      final m = result.moves.single;
      expect(m.rowId, 'r1');
      expect(m.word, 'Apple');
      expect(m.before!.box, 2);
      expect(m.after!.box, 3);
    });
  });

  group('applySession with self-check ratings (self-check-cards AC-05 – AC-10)', () {
    ({List<WordBox> boxes, List<SessionMove> moves}) rate(
      WordBox? before,
      WordOutcome outcome,
      SelfRating rating, {
      String side = 'en',
    }) {
      final r = row('r1', 'apple');
      return applySession([if (before != null) before], {r: outcome}, now,
          ratings: {r: (rating: rating, side: side)});
    }

    test('ratings move a flagged word from its box before the session', () {
      expect(rate(box('r1', 'apple', 4), WordOutcome.missed, SelfRating.dontRemember).boxes.single.box, 1);
      expect(rate(box('r1', 'apple', 4), WordOutcome.missed, SelfRating.hard).boxes.single.box, 3);
      expect(rate(box('r1', 'apple', 1), WordOutcome.missed, SelfRating.hard).boxes.single.box, 1);
      expect(rate(box('r1', 'apple', 4), WordOutcome.missed, SelfRating.medium).boxes.single.box, 4);
      expect(rate(null, WordOutcome.missed, SelfRating.medium).boxes.single.box, 1);
      expect(rate(box('r1', 'apple', 4), WordOutcome.hinted, SelfRating.easy).boxes.single.box, 5);
      expect(rate(box('r1', 'apple', 5), WordOutcome.hinted, SelfRating.easy).boxes.single.box, 5);
    });

    test('the next review is start of today plus intervalDays of the new box', () {
      final b = rate(box('r1', 'apple', 2), WordOutcome.hinted, SelfRating.easy).boxes.single;
      expect(b.box, 3);
      expect(b.dueAt, DateTime(2026, 10, 27));
      expect(b.lastUpDay, todayKey);
    });

    test('guard: Easy after a mistake counts as Medium; after a hint it stays Easy (AC-06, Q-2)', () {
      expect(rate(box('r1', 'apple', 3), WordOutcome.missed, SelfRating.easy).boxes.single.box, 3);
      expect(rate(box('r1', 'apple', 3), WordOutcome.hinted, SelfRating.easy).boxes.single.box, 4);
    });

    test('Easy moves up at most once a day; down moves always apply (AC-07)', () {
      final up = box('r1', 'apple', 3, lastUpDay: todayKey);
      expect(rate(up, WordOutcome.hinted, SelfRating.easy).boxes.single.box, 3);
      expect(rate(box('r1', 'apple', 3, lastUpDay: todayKey), WordOutcome.missed, SelfRating.hard).boxes.single.box, 2);
    });

    test('the card side is stored and the move carries the rating (AC-10)', () {
      final result = rate(box('r1', 'apple', 2), WordOutcome.missed, SelfRating.hard, side: 'uk');
      expect(result.boxes.single.lastCheckSide, 'uk');
      final m = result.moves.single;
      expect(m.rating, SelfRating.hard);
      expect(m.state, WordState.shaky);
      expect(m.before!.box, 2);
      expect(m.after!.box, 1);
    });

    test('a rated new word gets state new', () {
      final m = rate(null, WordOutcome.hinted, SelfRating.easy).moves.single;
      expect(m.state, WordState.isNew);
      expect(m.after!.box, 1);
    });

    test('a rating on a clean or unused word is ignored', () {
      final clean = rate(box('r1', 'apple', 2), WordOutcome.clean, SelfRating.dontRemember);
      expect(clean.boxes.single.box, 3);
      expect(clean.moves.single.rating, isNull);
      expect(clean.moves.single.state, WordState.knownWell);
      final unused = rate(box('r1', 'apple', 2), WordOutcome.unused, SelfRating.dontRemember);
      expect(unused.boxes.single.box, 2);
      expect(unused.moves.single.rating, isNull);
    });

    test('a clean word moves as before beside rated words (AC-08)', () {
      final a = row('a', 'apple'), b = row('b', 'pear');
      final result = applySession(
          [box('a', 'apple', 2), box('b', 'pear', 2)],
          {a: WordOutcome.clean, b: WordOutcome.missed},
          now,
          ratings: {b: (rating: SelfRating.dontRemember, side: 'uk')});
      final boxes = {for (final x in result.boxes) x.rowId: x.box};
      expect(boxes, {'a': 3, 'b': 1});
    });
  });

  group('nextReviewText (AC-12)', () {
    test('today, tomorrow, in N days', () {
      expect(nextReviewText(DateTime(2026, 10, 23), now), 'today');
      expect(nextReviewText(DateTime(2026, 10, 20), now), 'today');
      expect(nextReviewText(DateTime(2026, 10, 24), now), 'tomorrow');
      expect(nextReviewText(DateTime(2026, 10, 27), now), 'in 4 days');
      expect(nextReviewText(DateTime(2026, 11, 8), now), 'in 16 days');
    });
  });
}
