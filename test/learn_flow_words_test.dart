import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/flow_words.dart';

/// learn-welcome T4: the pure flow word rules (AC-05, AC-06, AC-13; ADR-0002).
void main() {
  WordPair row(String id, {String? source}) =>
      WordPair(word: 'w$id', rowId: id, sourceId: source);

  List<String> ids(List<WordPair> words) => [for (final w in words) w.rowId];

  List<WordPair> rows(int n, {String prefix = 'r', String? source}) =>
      [for (var i = 0; i < n; i++) row('$prefix$i', source: source)];

  group('cardWords (AC-05, owner 2026-11-01: every word)', () {
    test('the owner\'s case: 28 words, 22 not due yet: all 28 cards, in list order', () {
      // Boxes no longer pick the cards: none is passed in.
      final list = rows(28);
      final picked = cardWords(list);
      expect(picked.length, 28);
      expect(ids(picked), ids(list));
    });

    test('no cap: 50 words make 50 cards', () {
      expect(ids(cardWords(rows(50))), ids(rows(50)));
    });

    test('a copy: changing it leaves the words as they are', () {
      final list = rows(4);
      cardWords(list).removeLast();
      expect(list.length, 4);
    });
  });

  group('splitGroups (AC-06)', () {
    test('the decision page sample: a short other-source tail moves on', () {
      // 10 photo words, 4 film words, 16 typed words.
      final words = [
        ...rows(10, prefix: 'p', source: 'photo'),
        ...rows(4, prefix: 'f', source: 'film'),
        ...rows(16, prefix: 't'),
      ];
      final groups = splitGroups(words);
      expect([for (final g in groups) g.length], [10, 12, 8]);
      expect(ids(groups[0]), ids(words.sublist(0, 10)));
      expect(ids(groups[1]), ids(words.sublist(10, 22)));
      expect(ids(groups[2]), ids(words.sublist(22)));
      expect(ids(storyGroups(groups).expand((g) => g).toList()), ids(words));
    });

    test('a tail of 4 moves on, a tail of 5 stays', () {
      final four = [
        ...rows(8, source: 'a'),
        ...rows(4, prefix: 'b', source: 'b')
      ];
      expect([for (final g in splitGroups(four)) g.length], [8, 4]);
      final five = [
        ...rows(7, source: 'a'),
        ...rows(5, prefix: 'b', source: 'b'),
        ...rows(3, prefix: 'c', source: 'c'),
      ];
      expect([for (final g in splitGroups(five)) g.length], [12, 3]);
    });

    test('a group of one source stays whole', () {
      final words = rows(30, source: 'a');
      expect([for (final g in splitGroups(words)) g.length], [12, 12, 6]);
    });

    test('the last, short group keeps its tail', () {
      final words = [...rows(5, source: 'a'), ...rows(2, prefix: 'b')];
      expect([for (final g in splitGroups(words)) g.length], [7]);
    });

    test('typed words (null or empty sourceId) share one source', () {
      final words = [
        ...rows(10, source: 'a'),
        row('t0'),
        row('t1', source: ''),
      ];
      expect([for (final g in splitGroups(words)) g.length], [10, 2]);
    });

    test('4–7 words make one group; no words make none', () {
      expect(splitGroups(rows(4)).length, 1);
      expect(splitGroups(rows(7)).length, 1);
      expect(splitGroups(const []), isEmpty);
    });

    test('only the first 3 groups get a story', () {
      final groups = splitGroups(rows(36 + 5));
      expect(groups.length, 4);
      expect(storyGroups(groups), groups.take(3).toList());
    });
  });

  group('dialogWords (AC-13)', () {
    int easy(int n) => dialogWords(rows(n),
            dontRemember: const {}, hard: const {}, mode: FlowMode.easy)
        .length;
    int hard(int n) => dialogWords(rows(n),
            dontRemember: const {}, hard: const {}, mode: FlowMode.hard)
        .length;

    test('Easy: min(6, ceil(N/2)), at least 4, never more than N', () {
      expect(easy(4), 4);
      expect(easy(8), 4);
      expect(easy(9), 5);
      expect(easy(11), 6);
      expect(easy(36), 6);
      expect(easy(3), 3);
    });

    test('Hard: min(12, N)', () {
      expect(hard(4), 4);
      expect(hard(12), 12);
      expect(hard(36), 12);
    });

    test('dontRemember first, then hard, then list order', () {
      final words = rows(10);
      final picked = dialogWords(words,
          dontRemember: {'r7', 'r3'}, hard: {'r9', 'r1'}, mode: FlowMode.easy);
      expect(ids(picked), ['r3', 'r7', 'r1', 'r9', 'r0']);
    });

    test('dialogReplies: Easy 6, Hard 12', () {
      expect(dialogReplies(FlowMode.easy), 6);
      expect(dialogReplies(FlowMode.hard), 12);
    });
  });
}
