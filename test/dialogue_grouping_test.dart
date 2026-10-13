import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/story/word_grouping.dart';

/// get-words-from-subtitles-improvment T15: dialogue groups come first, are
/// any size, and other words follow mnemonic-story grouping.

WordPair row(String id, {String translation = 'переклад'}) =>
    WordPair(word: 'w$id', translation: translation, rowId: id);

List<String> ids(String prefix, int from, int to) =>
    [for (var i = from; i <= to; i++) '$prefix$i'];

FilmDialogue dialogue(String id, List<String> rowIds) => FilmDialogue()
  ..id = id
  ..lines = ['line']
  ..wordRowIds = rowIds;

WordGroup grp(String id, String name, List<String> rowIds,
        {String? storyRunId, String? dialogueId}) =>
    WordGroup()
      ..id = id
      ..name = name
      ..rowIds = rowIds
      ..storyRunId = storyRunId
      ..dialogueId = dialogueId;

/// [others] plain words o1..oN plus the given dialogue rows.
Session sessionWith(int others, Map<String, List<String>> dialogues) {
  final s = Session.create();
  final dialogueRows = {for (final r in dialogues.values) ...r};
  s.words = [
    for (final id in dialogueRows) row(id),
    for (final id in ids('o', 1, others)) row(id),
  ];
  s.dialogues = [
    for (final e in dialogues.entries) dialogue(e.key, e.value),
  ];
  return s;
}

String Function() counterIds() {
  var n = 0;
  return () => 'new${++n}';
}

List<WordGroup> dialogueGroups(List<WordGroup> groups) =>
    groups.where((g) => g.dialogueId != null).toList();

void main() {
  group('dialogue groups are any size (AC-15)', () {
    final dialogues = {
      'd1': ['a1'],
      'd2': ['b1', 'b2'],
      'd3': ['c1', 'c2', 'c3', 'c4'],
    };

    test('with 19 other words: the dialogue groups, then one "Other words"',
        () {
      final plan =
          planGrouping(sessionWith(19, dialogues), const {}, counterIds());
      expect(plan, isA<GroupingLocal>());
      final local = plan as GroupingLocal;
      expect(local.waiting, isEmpty);
      expect(local.groups.map((g) => g.dialogueId), ['d1', 'd2', 'd3', null]);
      expect(local.groups.map((g) => g.rowIds.length), [1, 2, 4, 19]);
      expect(local.groups.last.name, otherWordsName);
      expect(local.groups.last.rowIds, ids('o', 1, 19));
    });

    test('with 25 other words: only those are split, into groups of 7 to 19',
        () {
      final s = sessionWith(25, dialogues);
      final plan = planGrouping(s, const {}, counterIds());
      expect(plan, isA<GroupingAsk>());
      final ask = plan as GroupingAsk;
      expect(ask.words.map((w) => w.rowId), ids('o', 1, 25));
      expect(ask.keep, isEmpty);

      final result = applySplit(
          s,
          [
            SplitGroup(name: 'Food', rowIds: ids('o', 1, 13)),
            SplitGroup(name: 'Travel', rowIds: ids('o', 14, 25)),
          ],
          const {},
          counterIds());
      expect(result, isA<SplitOk>());
      final groups = (result as SplitOk).groups;
      expect(groups.map((g) => g.dialogueId), ['d1', 'd2', 'd3', null, null]);
      expect(groups.map((g) => g.rowIds.length), [1, 2, 4, 13, 12]);
      expect(result.waiting, isEmpty);
    });

    test('a dialogue group is named after its dialogue card', () {
      final s = sessionWith(0, {
        'd1': ['a1']
      });
      s.dialogues.single.lines = ['- A: Where is it?'];
      final groups = (planGrouping(s) as GroupingLocal).groups;
      expect(groups.single.name, 'Where is it?');
    });
  });

  group('one word, one group (AC-06)', () {
    test('a word in two dialogues goes to the first one\'s group', () {
      final s = sessionWith(0, {
        'd1': ['x1'],
        'd2': ['x1', 'y1'],
        'd3': ['x1'],
      });
      final groups = (planGrouping(s) as GroupingLocal).groups;
      expect(groups.map((g) => g.dialogueId), ['d1', 'd2']);
      expect(groups.map((g) => g.rowIds), [
        ['x1'],
        ['y1'],
      ]);
    });

    test('a dialogue word that is not a word to learn is in no group', () {
      final s = sessionWith(0, {
        'd1': ['a1', 'a2'],
        'd2': ['b1'],
      });
      s.words.firstWhere((w) => w.rowId == 'a2').translation = '';
      s.words.firstWhere((w) => w.rowId == 'b1').translation = '';
      final groups = (planGrouping(s) as GroupingLocal).groups;
      expect(groups.map((g) => g.rowIds), [
        ['a1'],
      ]);
    });

    test('a hidden dialogue has no group', () {
      final s = sessionWith(0, {
        'd1': ['a1']
      });
      s.dialogues.single.hidden = true;
      final groups = (planGrouping(s) as GroupingLocal).groups;
      expect(dialogueGroups(groups), isEmpty);
    });
  });

  group('existing groups stay (AC-17)', () {
    test('only new dialogue words in no group make dialogue groups', () {
      // Before the import: 10 words o1..o10, a story group of o1..o3 and the
      // "All words" group of the rest, selected.
      final s = sessionWith(10, {});
      s.groups = [
        grp('gs', 'Story', ids('o', 1, 3), storyRunId: 'run-1'),
        grp('ga', allWordsName, ids('o', 4, 10)),
      ];
      s.selectedGroupId = 'ga';
      s.groupedWordsKey = groupedWordsKey(s);
      // The import brings n1..n3 and two dialogues: d1 holds an old word and
      // a new one; d2 holds only an old word.
      s.words = [...s.words, row('n1'), row('n2'), row('n3')];
      s.dialogues = [
        dialogue('d1', ['o2', 'n1']),
        dialogue('d2', ['o5']),
      ];

      final groups = (planGrouping(s) as GroupingLocal).groups;
      final story = groups.firstWhere((g) => g.id == 'gs');
      expect(story.rowIds, ids('o', 1, 3));
      expect(story.storyRunId, 'run-1');
      expect(story.name, 'Story');
      final d1 = groups.singleWhere((g) => g.dialogueId == 'd1');
      expect(d1.rowIds, ['n1']);
      expect(groups.where((g) => g.dialogueId == 'd2'), isEmpty);
      final all = groups.firstWhere((g) => g.id == 'ga');
      expect(all.name, allWordsName);
      expect(all.rowIds, containsAll(ids('o', 4, 10)));
      expect(all.rowIds, containsAll(['n2', 'n3']));
      expect(all.rowIds, isNot(contains('n1')));
    });

    test('a dialogue group keeps its id and story when grouping runs again',
        () {
      final s = sessionWith(3, {
        'd1': ['a1', 'a2']
      });
      final first =
          (planGrouping(s, const {}, counterIds()) as GroupingLocal).groups;
      s.groups = [
        for (final g in first)
          g.dialogueId == null ? g : (g.copy()..storyRunId = 'run-1')
      ];
      s.groupedWordsKey = groupedWordsKey(s);
      s.words = [...s.words, row('o4')];

      final again =
          (planGrouping(s, const {}, counterIds()) as GroupingLocal).groups;
      final d1 = again.singleWhere((g) => g.dialogueId == 'd1');
      expect(d1.id, first.first.id);
      expect(d1.storyRunId, 'run-1');
      expect(d1.rowIds, ['a1', 'a2']);
      expect(again.last.rowIds, ids('o', 1, 4));
    });
  });

  group('other words follow mnemonic-story grouping (AC-25)', () {
    test('"Other words" of 12 and 15 more: the Worker splits them, keeping it',
        () {
      final s = sessionWith(12, {
        'd1': ['a1']
      });
      final first = (planGrouping(s) as GroupingLocal).groups;
      s.groups = first;
      s.groupedWordsKey = groupedWordsKey(s);
      s.words = [...s.words, for (final id in ids('o', 13, 27)) row(id)];

      final plan = planGrouping(s, const {}, counterIds());
      expect(plan, isA<GroupingAsk>());
      final ask = plan as GroupingAsk;
      expect(ask.keep.map((g) => g.name), [otherWordsName]);
      expect(ask.words.map((w) => w.rowId), ids('o', 1, 27));

      final other = ask.keep.single;
      final result = applySplit(
          s,
          [
            SplitGroup(id: other.id, name: other.name, rowIds: ids('o', 1, 19)),
            SplitGroup(name: 'Travel', rowIds: ids('o', 20, 27)),
          ],
          const {},
          counterIds());
      expect(result, isA<SplitOk>());
      final groups = (result as SplitOk).groups;
      expect(groups.map((g) => g.dialogueId), ['d1', null, null]);
      expect(groups[1].id, other.id);
      expect(groups.map((g) => g.rowIds.length), [1, 19, 8]);
    });

    test('fewer than 7 left over wait', () {
      final s = sessionWith(19, {
        'd1': ['a1']
      });
      s.groups = (planGrouping(s) as GroupingLocal).groups;
      s.groupedWordsKey = groupedWordsKey(s);
      s.words = [...s.words, for (final id in ids('o', 20, 22)) row(id)];

      final plan = planGrouping(s);
      expect(plan, isA<GroupingLocal>());
      expect((plan as GroupingLocal).waiting, ids('o', 20, 22));
      expect(plan.groups.map((g) => g.dialogueId), ['d1', null]);
    });
  });

  group('a dialogue group follows its dialogue (AC-26)', () {
    test('an edited-away word moves to "Other words"; the group stays', () {
      final s = sessionWith(2, {
        'd1': ['a1', 'a2']
      });
      s.groups = (planGrouping(s) as GroupingLocal).groups;
      s.groupedWordsKey = groupedWordsKey(s);
      // afterEdit dropped a2 from the dialogue; it is still a word to learn.
      s.dialogues.single.wordRowIds = ['a1'];
      s.words.firstWhere((w) => w.rowId == 'a2').word = 'edited';

      final groups = (planGrouping(s) as GroupingLocal).groups;
      expect(groups.first.rowIds, ['a1']);
      expect(groups.last.rowIds, containsAll(['a2', 'o1', 'o2']));
    });

    test('a dialogue that is gone takes its group with it', () {
      final s = sessionWith(2, {
        'd1': ['a1']
      });
      s.groups = (planGrouping(s) as GroupingLocal).groups;
      s.groups.first.storyRunId = 'run-1';
      s.groupedWordsKey = groupedWordsKey(s);
      s.dialogues = [];
      s.words.firstWhere((w) => w.rowId == 'a1').word = 'edited';

      final groups = (planGrouping(s) as GroupingLocal).groups;
      expect(dialogueGroups(groups), isEmpty);
      expect(groups.single.rowIds, containsAll(['a1', 'o1', 'o2']));
    });
  });

  test('groupedWordsKey changes when a dialogue loses a word', () {
    final s = sessionWith(2, {
      'd1': ['a1', 'a2']
    });
    final before = groupedWordsKey(s);
    s.dialogues.single.wordRowIds = ['a1'];
    expect(groupedWordsKey(s), isNot(before));
  });

  test('a session without dialogues keeps the "All words" name', () {
    final groups = (planGrouping(sessionWith(3, {})) as GroupingLocal).groups;
    expect(groups.single.name, allWordsName);
  });
}
