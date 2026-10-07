import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/story/word_grouping.dart';

WordPair row(String id, String word, {String translation = 'переклад', String definition = ''}) =>
    WordPair(word: word, translation: translation, definition: definition, rowId: id);

/// A session with [n] filled rows r1..rn (words w1..wn).
Session sessionOf(int n) {
  final s = Session.create();
  s.words = [for (var i = 1; i <= n; i++) row('r$i', 'w$i')];
  return s;
}

List<String> ids(int from, int to) => [for (var i = from; i <= to; i++) 'r$i'];

WordGroup grp(String id, String name, List<String> rowIds, {String? storyRunId, List<String>? storyWords}) =>
    WordGroup()
      ..id = id
      ..name = name
      ..rowIds = rowIds
      ..storyRunId = storyRunId
      ..storyWords = storyWords ?? [];

/// The grouping state a finished grouping would have left.
void markGrouped(Session s) => s.groupedWordsKey = groupedWordsKey(s);

String Function() counterIds() {
  var n = 0;
  return () => 'new${++n}';
}

void main() {
  group('groupedWordsKey (AC-03)', () {
    test('ignores a translation or definition edit and the row order', () {
      final s = sessionOf(3);
      final before = groupedWordsKey(s);
      s.words[0].translation = 'інший';
      s.words[1].definition = 'a definition';
      s.words = s.words.reversed.toList();
      expect(groupedWordsKey(s), before);
    });

    test('changes when an English word is added, edited or deleted', () {
      final s = sessionOf(3);
      final before = groupedWordsKey(s);
      s.words = [...s.words, row('r4', 'w4')];
      final added = groupedWordsKey(s);
      expect(added, isNot(before));
      s.words[0].word = 'edited';
      final edited = groupedWordsKey(s);
      expect(edited, isNot(added));
      s.words = s.words.sublist(1);
      expect(groupedWordsKey(s), isNot(edited));
    });

    test('changes when a row becomes or stops being a word to learn', () {
      final s = sessionOf(3);
      final before = groupedWordsKey(s);
      s.words[0].translation = '';
      expect(groupedWordsKey(s), isNot(before));
      s.words[0].translation = 'переклад';
      expect(groupedWordsKey(s), before);
    });

    test('a word with only a definition counts as a word to learn', () {
      final s = Session.create()..words = [row('a', 'x', translation: '', definition: 'd')];
      expect(groupedWordsKey(s), contains('a'));
    });
  });

  group('planGrouping, a session of 19 words or fewer (AC-02, AC-02b)', () {
    test('one group "All words" with every word, whatever its size', () {
      for (final n in [1, 5, 19]) {
        final plan = planGrouping(sessionOf(n), const {}, counterIds());
        expect(plan, isA<GroupingLocal>());
        final groups = (plan as GroupingLocal).groups;
        expect(groups.length, 1);
        expect(groups.single.name, 'All words');
        expect(groups.single.rowIds, ids(1, n));
        expect(plan.waiting, isEmpty);
      }
    });

    test('keeps the id of the group it already had', () {
      final s = sessionOf(5)..groups = [grp('g1', 'Old', ids(1, 4))];
      final plan = planGrouping(s, const {}, counterIds()) as GroupingLocal;
      expect(plan.groups.single.id, 'g1');
      expect(plan.groups.single.rowIds, ids(1, 5));
    });

    test('words added beside a group with a story form their own group of any size', () {
      final s = sessionOf(14)
        ..groups = [grp('story', 'All words', ids(1, 12), storyRunId: 'run1', storyWords: [])];
      final plan = planGrouping(s, const {}, counterIds()) as GroupingLocal;
      expect(plan.groups.length, 2);
      expect(plan.groups[0].id, 'story');
      expect(plan.groups[0].rowIds, ids(1, 12));
      expect(plan.groups[1].rowIds, ids(13, 14));
      expect(plan.waiting, isEmpty);
    });

    test('a second round of added words extends the same own group', () {
      final s = sessionOf(15)
        ..groups = [
          grp('story', 'All words', ids(1, 12), storyRunId: 'run1'),
          grp('own', 'New words', ids(13, 14)),
        ];
      final plan = planGrouping(s, const {}, counterIds()) as GroupingLocal;
      expect(plan.groups.map((g) => g.id), ['story', 'own']);
      expect(plan.groups[1].rowIds, ids(13, 15));
    });

    test('a group whose run is in progress counts as a group with a story', () {
      final s = sessionOf(14)..groups = [grp('g1', 'All words', ids(1, 12))];
      final plan = planGrouping(s, {'g1'}, counterIds()) as GroupingLocal;
      expect(plan.groups.map((g) => g.id), ['g1', 'new1']);
      expect(plan.groups[0].rowIds, ids(1, 12));
      expect(plan.groups[1].rowIds, ids(13, 14));
    });

    test('a story group follows its words and the rest stay outside it', () {
      final s = sessionOf(12)
        ..words = [for (var i = 1; i <= 12; i++) if (i != 3) row('r$i', 'w$i')]
        ..groups = [grp('story', 'All words', ids(1, 11), storyRunId: 'run1')];
      final plan = planGrouping(s, const {}, counterIds()) as GroupingLocal;
      expect(plan.groups.length, 2);
      expect(plan.groups[0].rowIds, [...ids(1, 2), ...ids(4, 11)]);
      expect(plan.groups[1].rowIds, ['r12']);
    });
  });

  group('planGrouping, unchanged (AC-03)', () {
    test('is unchanged when the key matches, and a translation edit does not change it', () {
      final s = sessionOf(25)..groups = [grp('g', 'A', ids(1, 25))];
      markGrouped(s);
      expect(planGrouping(s), isA<GroupingUnchanged>());
      s.words[0].translation = 'інший';
      expect(planGrouping(s), isA<GroupingUnchanged>());
    });

    test('runs again after an English word edit', () {
      final s = sessionOf(25);
      markGrouped(s);
      s.words[0].word = 'edited';
      expect(planGrouping(s), isNot(isA<GroupingUnchanged>()));
    });

    test('a session never grouped is planned', () {
      expect(planGrouping(sessionOf(5)), isA<GroupingLocal>());
    });
  });

  group('planGrouping, more than 19 words (AC-05)', () {
    test('asks for a split of all the words when nothing is grouped', () {
      final plan = planGrouping(sessionOf(25), const {}, counterIds());
      expect(plan, isA<GroupingAsk>());
      final ask = plan as GroupingAsk;
      expect(ask.keep, isEmpty);
      expect(ask.words.map((w) => w.rowId), ids(1, 25));
      expect(ask.words.first.word, 'w1');
    });

    test('never sends a group with a story or a run in progress', () {
      final s = sessionOf(45)
        ..groups = [
          grp('story', 'S', ids(1, 10), storyRunId: 'run1'),
          grp('busy', 'B', ids(11, 20)),
        ];
      final ask = planGrouping(s, {'busy'}, counterIds()) as GroupingAsk;
      expect(ask.words.map((w) => w.rowId), ids(21, 45));
      expect(ask.keep, isEmpty);
    });

    test('sends groups without a story as keep, with their words', () {
      final s = sessionOf(30)
        ..groups = [grp('k', 'Kitchen', ids(1, 10)), grp('story', 'S', ids(11, 20), storyRunId: 'r')];
      final ask = planGrouping(s, const {}, counterIds()) as GroupingAsk;
      expect(ask.keep.map((g) => g.id), ['k']);
      expect(ask.keep.single.name, 'Kitchen');
      expect(ask.keep.single.rowIds, ids(1, 10));
      expect(ask.words.map((w) => w.rowId).toSet(), {...ids(1, 10), ...ids(21, 30)});
    });

    test('fewer than 7 words outside story groups, no group to take them, wait', () {
      final s = sessionOf(25)
        ..groups = [grp('a', 'A', ids(1, 19), storyRunId: 'r1')];
      final plan = planGrouping(s, const {}, counterIds()) as GroupingLocal;
      expect(plan.waiting, ids(20, 25));
      expect(plan.groups.map((g) => g.id), ['a']);
    });

    test('fewer than 7 words and a group without a story with room ask the AI', () {
      final s = sessionOf(25)
        ..groups = [
          grp('a', 'A', ids(1, 12), storyRunId: 'r1'),
          grp('b', 'B', ids(13, 20)),
        ];
      final ask = planGrouping(s, const {}, counterIds()) as GroupingAsk;
      expect(ask.keep.single.id, 'b');
      expect(ask.words.map((w) => w.rowId).toSet(), {...ids(13, 20), ...ids(21, 25)});
    });

    test('fewer than 7 words and every group without a story full, wait', () {
      final s = sessionOf(25)
        ..groups = [grp('b', 'B', ids(1, 19)), ];
      final plan = planGrouping(s, const {}, counterIds()) as GroupingLocal;
      expect(plan.waiting, ids(20, 25));
      expect(plan.groups.single.rowIds, ids(1, 19));
    });

    test('a deleted word leaves its group with no call to the Worker', () {
      final s = sessionOf(30)
        ..groups = [grp('a', 'A', ids(1, 15)), grp('b', 'B', ids(16, 30))];
      s.words = [for (final w in s.words) if (w.rowId != 'r2') w];
      final plan = planGrouping(s, const {}, counterIds()) as GroupingLocal;
      expect(plan.groups.map((g) => g.id), ['a', 'b']);
      expect(plan.groups[0].rowIds, [...ids(1, 1), ...ids(3, 15)]);
      expect(plan.waiting, isEmpty);
    });

    test('a group without a story that shrank below 7 is dissolved and its words regrouped', () {
      final s = sessionOf(30)
        ..groups = [grp('a', 'A', ids(1, 10)), grp('b', 'B', ids(11, 25))];
      s.words = [for (final w in s.words) if (!{'r1', 'r2', 'r3', 'r4'}.contains(w.rowId)) w];
      final ask = planGrouping(s, const {}, counterIds()) as GroupingAsk;
      expect(ask.keep.map((g) => g.id), ['b']);
      expect(ask.words.map((w) => w.rowId).toSet(), {...ids(5, 10), ...ids(11, 30)});
      expect(ask.keep.single.rowIds, ids(11, 25));
    });
  });

  group('applySplit (AC-04, AC-05)', () {
    SplitGroup split(String name, List<String> rowIds, {String? id}) =>
        SplitGroup(id: id, name: name, rowIds: rowIds);

    test('a valid split makes new groups with new ids and the names it gave', () {
      final s = sessionOf(25);
      final result = applySplit(s, [split('Food', ids(1, 12)), split('Travel', ids(13, 25))], const {}, counterIds());
      expect(result, isA<SplitOk>());
      final ok = result as SplitOk;
      expect(ok.groups.map((g) => g.name), ['Food', 'Travel']);
      expect(ok.groups.map((g) => g.id), ['new1', 'new2']);
      expect(ok.groups[1].rowIds, ids(13, 25));
      expect(ok.waiting, isEmpty);
    });

    test('a word left out is invalid', () {
      final s = sessionOf(25);
      expect(applySplit(s, [split('A', ids(1, 12)), split('B', ids(13, 24))]), isA<SplitInvalid>());
    });

    test('a word in two groups is invalid', () {
      final s = sessionOf(25);
      expect(applySplit(s, [split('A', ids(1, 13)), split('B', ids(13, 25))]), isA<SplitInvalid>());
    });

    test('a word that was not asked is invalid', () {
      final s = sessionOf(25);
      expect(applySplit(s, [split('A', ids(1, 12)), split('B', [...ids(13, 25), 'zzz'])]), isA<SplitInvalid>());
    });

    test('a group above 19 or below 7 is invalid', () {
      final s = sessionOf(26);
      expect(applySplit(s, [split('A', ids(1, 20)), split('B', ids(21, 26))]), isA<SplitInvalid>());
      expect(applySplit(s, [split('A', ids(1, 21)), split('B', ids(22, 26))]), isA<SplitInvalid>());
      final s2 = sessionOf(25);
      expect(applySplit(s2, [split('A', ids(1, 20)), split('B', ids(21, 25))]), isA<SplitInvalid>());
    });

    test('an empty group is invalid', () {
      final s = sessionOf(25);
      expect(applySplit(s, [split('A', ids(1, 25)), split('B', [])]), isA<SplitInvalid>());
    });

    test('a kept group keeps its id, name and words and gains words', () {
      final s = sessionOf(30)
        ..groups = [grp('k', 'Kitchen', ids(1, 10)), grp('story', 'S', ids(11, 20), storyRunId: 'r')];
      final result = applySplit(
        s,
        [split('Whatever the AI says', [...ids(1, 10), ...ids(21, 23)], id: 'k'), split('Rest', ids(24, 30))],
        const {},
        counterIds(),
      );
      final ok = result as SplitOk;
      expect(ok.groups.map((g) => g.id), ['k', 'story', 'new1']);
      expect(ok.groups[1].rowIds, ids(11, 20));
      expect(ok.groups[0].name, 'Kitchen');
      expect(ok.groups[0].rowIds, [...ids(1, 10), ...ids(21, 23)]);
      expect(ok.groups[2].rowIds, ids(24, 30));
    });

    test('a kept group that loses a word, is renamed away, is missing or unknown is invalid', () {
      final s = sessionOf(30)..groups = [grp('k', 'Kitchen', ids(1, 10))];
      // loses r10 to another group
      expect(
        applySplit(s, [split('', ids(1, 9), id: 'k'), split('B', ids(10, 30))]),
        isA<SplitInvalid>(),
      );
      // kept group missing from the answer
      expect(applySplit(s, [split('B', ids(1, 15)), split('C', ids(16, 30))]), isA<SplitInvalid>());
      // unknown id
      expect(
        applySplit(s, [split('', ids(1, 15), id: 'nope'), split('C', ids(16, 30))]),
        isA<SplitInvalid>(),
      );
      // the same kept id twice
      expect(
        applySplit(s, [split('', ids(1, 10), id: 'k'), split('', ids(11, 20), id: 'k'), split('C', ids(21, 30))]),
        isA<SplitInvalid>(),
      );
    });

    test('a kept group grown above 19 is invalid', () {
      final s = sessionOf(40)..groups = [grp('k', 'Kitchen', ids(1, 15))];
      expect(
        applySplit(s, [split('', ids(1, 21), id: 'k'), split('B', ids(22, 40))]),
        isA<SplitInvalid>(),
      );
    });

    test('a group with a story is never touched by the split', () {
      final s = sessionOf(30)..groups = [grp('story', 'S', ids(1, 10), storyRunId: 'r')];
      // the AI answers about words it was never given
      expect(
        applySplit(s, [split('A', ids(1, 15)), split('B', ids(16, 30))]),
        isA<SplitInvalid>(),
      );
      final ok = applySplit(s, [split('A', ids(11, 20)), split('B', ids(21, 30))], const {}, counterIds()) as SplitOk;
      expect(ok.groups.map((g) => g.id), ['story', 'new1', 'new2']);
      expect(ok.groups[0].rowIds, ids(1, 10));
    });

    test('fewer than 7 leftover words wait when they cannot make a group', () {
      final s = sessionOf(25)
        ..groups = [grp('a', 'A', ids(1, 12), storyRunId: 'r1'), grp('b', 'B', ids(13, 19))];
      // 6 new words (r20..r25); the AI cannot fit them into b (room 12) -> it may put them in a small group
      final ok = applySplit(
        s,
        [split('', ids(13, 19), id: 'b'), split('Rest', ids(20, 25))],
        const {},
        counterIds(),
      ) as SplitOk;
      expect(ok.waiting, ids(20, 25));
      expect(ok.groups.map((g) => g.id), ['a', 'b']);
    });

    test('a small group is invalid when there were 7 or more new words', () {
      final s = sessionOf(25);
      expect(applySplit(s, [split('A', ids(1, 20)), split('B', ids(21, 25))]), isA<SplitInvalid>());
    });

    test('a session of 19 words or fewer is never split by the AI', () {
      final s = sessionOf(10);
      expect(applySplit(s, [split('A', ids(1, 10))]), isA<SplitInvalid>());
    });
  });

  group('groupWords (AC-17)', () {
    test('returns the current words by row id, in the group order', () {
      final s = sessionOf(5);
      final g = grp('g', 'G', ['r3', 'r1']);
      expect(groupWords(s, g).map((w) => w.word), ['w3', 'w1']);
    });

    test('a deleted word leaves and an edited word shows its new form', () {
      final s = sessionOf(5);
      final g = grp('g', 'G', ids(1, 5));
      s.words = [for (final w in s.words) if (w.rowId != 'r2') w];
      s.words.firstWhere((w) => w.rowId == 'r3').word = 'edited';
      expect(groupWords(s, g).map((w) => w.word), ['w1', 'edited', 'w4', 'w5']);
    });

    test('a row that stopped being a word to learn leaves', () {
      final s = sessionOf(3);
      s.words[1].translation = '';
      expect(groupWords(s, grp('g', 'G', ids(1, 3))).map((w) => w.rowId), ['r1', 'r3']);
    });
  });

  group('isOutdated (AC-17)', () {
    Session withStory() {
      final s = sessionOf(4);
      return s;
    }

    final storyWords = ['w1', 'w2', 'w3', 'w4'];

    test('a group with no story is never outdated', () {
      final s = withStory();
      expect(isOutdated(s, grp('g', 'G', ids(1, 4))), isFalse);
    });

    test('is not outdated when the words are as they were, or only a translation changed', () {
      final s = withStory();
      final g = grp('g', 'G', ids(1, 4), storyRunId: 'run', storyWords: storyWords);
      expect(isOutdated(s, g), isFalse);
      s.words[0].translation = 'інший';
      s.words[1].definition = 'new definition';
      expect(isOutdated(s, g), isFalse);
    });

    test('is outdated when a word is deleted, edited or stops being a word to learn', () {
      final g = grp('g', 'G', ids(1, 4), storyRunId: 'run', storyWords: storyWords);
      final deleted = withStory()..words = withStory().words.sublist(1);
      expect(isOutdated(deleted, g), isTrue);
      final edited = withStory()..words[0].word = 'changed';
      expect(isOutdated(edited, g), isTrue);
      final stopped = withStory()..words[0].translation = '';
      expect(isOutdated(stopped, g), isTrue);
    });
  });

  group('selectedGroupIdOf (AC-01)', () {
    test('the remembered group', () {
      final s = sessionOf(3)
        ..groups = [grp('a', 'A', ['r1']), grp('b', 'B', ['r2'])]
        ..selectedGroupId = 'b';
      expect(selectedGroupIdOf(s), 'b');
    });

    test('the first group when none was selected or the remembered one is gone', () {
      final s = sessionOf(3)..groups = [grp('a', 'A', ['r1']), grp('b', 'B', ['r2'])];
      expect(selectedGroupIdOf(s), 'a');
      s.selectedGroupId = 'gone';
      expect(selectedGroupIdOf(s), 'a');
    });

    test('none when there are no groups', () {
      expect(selectedGroupIdOf(sessionOf(3)), isNull);
    });
  });
}
