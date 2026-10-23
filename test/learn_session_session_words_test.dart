import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/session/session_words.dart';

/// learn-redesign T4: the pure word picker (AC-05, AC-06, AC-07, AC-14;
/// ADR-0005).
void main() {
  final now = DateTime(2026, 10, 23, 15, 30);
  final today = DateTime(2026, 10, 23);

  String id(int i) => 'r$i';
  String word(int i) => 'word$i';

  WordCollection collection(int n, {List<List<int>> groups = const []}) =>
      WordCollection()
        ..collectionId = 'c'
        ..words = [
          for (var i = 0; i < n; i++)
            WordPair(word: word(i), translation: 't$i', rowId: id(i)),
        ]
        ..groups = [
          for (var g = 0; g < groups.length; g++)
            WordGroup()
              ..id = 'g$g'
              ..name = 'Group $g'
              ..rowIds = [for (final i in groups[g]) id(i)],
        ];

  WordBox box(int i, {required DateTime dueAt, int n = 2}) => WordBox()
    ..rowId = id(i)
    ..word = word(i)
    ..box = n
    ..dueAt = dueAt;

  final past = DateTime(2026, 10, 20);
  final future = DateTime(2026, 10, 30);

  List<String> ids(List<WordPair> words) => [for (final w in words) w.rowId];
  List<int> range(int from, int to) => [for (var i = from; i < to; i++) i];

  /// Every word known (a box, not due).
  void allKnown(WordCollection c) => c.boxes = [
        for (var i = 0; i < c.words.length; i++) box(i, dueAt: future)
      ];

  SessionPick pick(WordCollection c,
          {bool split = true,
          int? wordsPerSession,
          int? lastGroup,
          int? skipGroup,
          List<String>? rowIds}) =>
      pickSessionWords(c,
          split: split,
          wordsPerSession: wordsPerSession,
          lastGroup: lastGroup,
          skipGroup: skipGroup,
          rowIds: rowIds,
          now: now);

  test('split shows at 20 words to learn', () {
    expect(splitShowsAt, 20);
  });

  group('under 20 words', () {
    test('15 words → all, split or not, no group', () {
      final c = collection(15);
      for (final split in [true, false]) {
        final p = pick(c, split: split, wordsPerSession: 10);
        expect(ids(p.words), [for (var i = 0; i < 15; i++) id(i)]);
        expect(p.groupIndex, isNull);
        expect(sessionGroupLabel(p), '');
      }
    });

    test('unfilled rows and rows without a row id are not words to learn', () {
      final c = collection(3)
        ..words.add(WordPair(word: 'empty', rowId: 'x'))
        ..words.add(WordPair(word: 'noid', translation: 't'));
      expect(ids(pick(c).words), ['r0', 'r1', 'r2']);
    });
  });

  group('sessionGroups', () {
    void expectCover(List<List<WordPair>> parts, int n) {
      for (final part in parts) {
        expect(part.length, inInclusiveRange(7, 12));
      }
      final all = [for (final p in parts) ...ids(p)];
      expect(all.length, n);
      expect(all.toSet(), {for (var i = 0; i < n; i++) id(i)});
    }

    test(
        '34 words with AI groups and waiting words → parts of 7–12 in group order',
        () {
      // Groups out of row order; 30..33 are waiting words (in no group).
      final c = collection(34, groups: [range(15, 30), range(0, 15)]);
      final parts = sessionGroups(c);
      expectCover(parts, 34);
      final flat = [for (final p in parts) ...ids(p)];
      expect(flat, [
        for (final i in [...range(15, 30), ...range(0, 15), ...range(30, 34)])
          id(i),
      ]);
    });

    test('no groups (grouping not done or failed) → row order', () {
      final c = collection(34);
      final parts = sessionGroups(c);
      expectCover(parts, 34);
      expect([for (final p in parts) ...ids(p)],
          [for (var i = 0; i < 34; i++) id(i)]);
    });

    test('a word in two groups appears once; a deleted row is skipped', () {
      final c = collection(20, groups: [
        [...range(0, 10), 99],
        range(5, 20),
      ]);
      final parts = sessionGroups(c);
      expectCover(parts, 20);
      expect([for (final p in parts) ...ids(p)],
          [for (var i = 0; i < 20; i++) id(i)]);
    });

    test('every size from 14 to 60 cuts into parts of 7–12', () {
      for (var n = 14; n <= 60; n++) {
        expectCover(sessionGroups(collection(n)), n);
      }
    });
  });

  group('split on, 20+ words', () {
    // 34 words in row order → parts 12 / 11 / 11: [0..11], [12..22], [23..33].
    test('first group holding a due word', () {
      final c = collection(34);
      allKnown(c);
      c.boxes[25] = box(25, dueAt: past);
      c.boxes[14] = box(14, dueAt: past);
      final p = pick(c, lastGroup: 2);
      expect(p.groupIndex, 1);
      expect(p.groupCount, 3);
      expect(ids(p.words), [for (final i in range(12, 23)) id(i)]);
      expect(p.dueRowIds, {id(14)});
      expect(p.newRowIds, isEmpty);
    });

    test('no due word → first group holding a new word', () {
      final c = collection(34);
      allKnown(c);
      c.boxes.removeAt(30); // r30 has no box: new.
      final p = pick(c, lastGroup: 0);
      expect(p.groupIndex, 2);
      expect(p.newRowIds, {id(30)});
      expect(p.dueRowIds, isEmpty);
    });

    test('a fresh collection starts at the first group', () {
      expect(pick(collection(34)).groupIndex, 0);
    });

    test('all known → the group after the last one, wrapping', () {
      final c = collection(34);
      allKnown(c);
      expect(pick(c).groupIndex, 0);
      expect(pick(c, lastGroup: 0).groupIndex, 1);
      expect(pick(c, lastGroup: 2).groupIndex, 0);
      // A stale index from a bigger collection still wraps.
      expect(pick(c, lastGroup: 5).groupIndex, 0);
    });

    test('Next group skips the group just played', () {
      final c = collection(34);
      allKnown(c);
      c.boxes[1] = box(1, dueAt: past); // group 0 due
      c.boxes[30] = box(30, dueAt: past); // group 2 due
      expect(pick(c).groupIndex, 0);
      expect(pick(c, skipGroup: 0).groupIndex, 2);

      final known = collection(34);
      allKnown(known);
      known.boxes.removeAt(5); // group 0 new only
      expect(pick(known, skipGroup: 0).groupIndex, 1); // after the skipped one

      final allDone = collection(34);
      allKnown(allDone);
      expect(pick(allDone, skipGroup: 2).groupIndex, 0); // wraps
      // The third rule starts after the skipped group, not the last one.
      expect(pick(allDone, skipGroup: 1, lastGroup: 0).groupIndex, 2);
    });

    test('label names the group 1-based with its word count', () {
      final c = collection(34);
      allKnown(c);
      c.boxes[14] = box(14, dueAt: past);
      expect(sessionGroupLabel(pick(c)), 'Group 2 of 3 · 11 words');
    });
  });

  group('split off, 20+ words', () {
    // 40 words: r0..r4 due, r10..r14 new (no box), the rest known.
    WordCollection mixed() {
      final c = collection(40);
      c.boxes = [
        for (var i = 0; i < 40; i++)
          if (i < 5)
            box(i, dueAt: past)
          else if (i < 10 || i >= 15)
            box(i, dueAt: future),
      ];
      return c;
    }

    final order = [
      ...range(0, 5),
      ...range(10, 15),
      ...range(5, 10),
      ...range(15, 40),
    ].map(id).toList();

    test('due, then new, then others, capped at 10/20/30/all', () {
      for (final cap in [10, 20, 30, null]) {
        final p = pick(mixed(), split: false, wordsPerSession: cap);
        expect(ids(p.words), order.take(cap ?? 40).toList(),
            reason: 'cap $cap');
        expect(p.groupIndex, isNull);
        expect(sessionGroupLabel(p), '');
      }
    });

    test('due and new ids are of the chosen words', () {
      final p = pick(mixed(), split: false, wordsPerSession: 10);
      expect(p.dueRowIds, range(0, 5).map(id).toSet());
      expect(p.newRowIds, range(10, 15).map(id).toSet());
    });

    test('a box of an edited English word does not count', () {
      final c = mixed();
      c.words[20].word = 'changed';
      final p = pick(c, split: false, wordsPerSession: 20);
      expect(p.newRowIds, contains(id(20)));
    });
  });

  test('explicit rowIds win, in row order', () {
    final c = collection(34);
    final p = pick(c, rowIds: [id(20), id(3), 'gone'], split: true);
    expect(ids(p.words), [id(3), id(20)]);
    expect(p.groupIndex, isNull);
    expect(sessionGroupLabel(p), '');
  });

  test('dueCount counts due words to learn', () {
    final c = collection(10);
    c.boxes = [
      box(0, dueAt: past),
      box(1, dueAt: today),
      box(2, dueAt: future),
      box(42, dueAt: past), // a deleted row
    ];
    expect(dueCount(c, now), 2);
  });
}
