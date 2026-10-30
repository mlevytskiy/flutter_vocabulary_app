import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';

/// learn-welcome T3: the pure self-check rules (AC-07, AC-08).
void main() {
  final now = DateTime(2026, 10, 30, 15, 30);
  const todayKey = '2026-10-30';
  final r = WordPair(word: ' Apple ', rowId: 'r1');

  WordBox box(int n, {String lastUpDay = '', String side = ''}) => WordBox()
    ..rowId = 'r1'
    ..word = 'apple'
    ..box = n
    ..lastUpDay = lastUpDay
    ..lastCheckSide = side;

  int to(WordBox? b, SelfRating s, {bool mistake = false}) =>
      rateBox(r, b, s, now, side: 'uk', afterMistake: mistake).box;

  List<int> row(SelfRating s) =>
      [for (final b in [null, box(1), box(3), box(5)]) to(b, s)];

  test('ratings from each box (new, 1, 3, 5)', () {
    expect(row(SelfRating.dontRemember), [1, 1, 1, 1]);
    expect(row(SelfRating.hard), [1, 1, 2, 4]);
    expect(row(SelfRating.medium), [1, 1, 3, 5]);
    expect(row(SelfRating.easy), [1, 2, 4, 5]);
  });

  test('easy after a mistake counts as medium', () {
    expect(to(box(3), SelfRating.easy, mistake: true), 3);
    expect(to(null, SelfRating.easy, mistake: true), 1);
    expect(to(box(3), SelfRating.hard, mistake: true), 2);
  });

  test('up at most once a day; down always applies', () {
    final b = box(3, lastUpDay: todayKey);
    expect(to(b, SelfRating.easy), 3);
    expect(to(b, SelfRating.hard), 2);
    expect(to(b, SelfRating.dontRemember), 1);
    expect(to(box(3, lastUpDay: '2026-10-29'), SelfRating.easy), 4);
  });

  test('rateBox sets id, key word, due, lastUpDay and side', () {
    final before = box(2, side: 'en');
    final after = rateBox(r, before, SelfRating.easy, now, side: 'uk');
    expect(after.rowId, 'r1');
    expect(after.word, 'apple');
    expect(after.box, 3);
    expect(after.dueAt, DateTime(2026, 10, 30 + 4));
    expect(after.lastUpDay, todayKey);
    expect(after.lastCheckSide, 'uk');
    expect(before.box, 2);
    expect(before.lastCheckSide, 'en');
  });

  test('a down move or a stay keeps lastUpDay', () {
    final b = box(3, lastUpDay: '2026-10-29');
    expect(rateBox(r, b, SelfRating.hard, now, side: 'en').lastUpDay,
        '2026-10-29');
    expect(rateBox(r, b, SelfRating.medium, now, side: 'en').lastUpDay,
        '2026-10-29');
    expect(rateBox(r, null, SelfRating.medium, now, side: 'en').lastUpDay,
        todayKey);
  });

  test('nextSide', () {
    expect(nextSide(null), 'uk');
    expect(nextSide(box(1)), 'uk');
    expect(nextSide(box(1, side: 'en')), 'uk');
    expect(nextSide(box(1, side: 'uk')), 'en');
  });

  test('boxLabel names the box a button leads to', () {
    expect(boxLabel(box(3), SelfRating.easy, now), 'Box 4');
    expect(boxLabel(box(3), SelfRating.easy, now, afterMistake: true), 'Box 3');
    expect(boxLabel(null, SelfRating.dontRemember, now), 'Box 1');
    expect(
        boxLabel(box(3, lastUpDay: todayKey), SelfRating.easy, now), 'Box 3');
  });
}
