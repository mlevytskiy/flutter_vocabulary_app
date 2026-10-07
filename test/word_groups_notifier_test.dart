import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/story/word_grouping.dart';
import 'package:flutter_vocabulary_app/core/story/word_groups_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// mnemonic-story T14: the word-groups notifier groups a session when its words
/// changed, keeps the selection, and leaves the current session alone when it
/// works on a History session (AC-01 – AC-05, AC-11).

class FakeStoryApi extends StoryApiService {
  final List<List<GroupingWord>> asked = [];
  final List<List<WordGroup>> keeps = [];
  Future<List<SplitGroup>> Function(List<GroupingWord>, List<WordGroup>)? reply;

  @override
  Future<List<SplitGroup>> group(List<GroupingWord> words, List<WordGroup> keep) {
    asked.add(words);
    keeps.add(keep);
    return reply!(words, keep);
  }
}

WordPair row(String id, String word) =>
    WordPair(word: word, translation: 'переклад', rowId: id);

Session sessionOf(int n, {String prefix = 'r'}) {
  final s = Session.create();
  s.words = [for (var i = 1; i <= n; i++) row('$prefix$i', 'w$prefix$i')];
  return s;
}

List<String> ids(int from, int to, {String prefix = 'r'}) =>
    [for (var i = from; i <= to; i++) '$prefix$i'];

/// A split of 25 words r1..r25 into 13 + 12.
List<SplitGroup> splitOf25(List<GroupingWord> words, List<WordGroup> keep) => [
      SplitGroup(name: 'Food', rowIds: ids(1, 13)),
      SplitGroup(name: 'Travel', rowIds: ids(14, 25)),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
  });

  late Directory dir;
  late SessionStore store;
  late StoryRunStore runStore;
  late FakeStoryApi api;
  late ProviderContainer container;
  late List<String> started; // "<sessionId>:<groupId>" of each hook call

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('word_groups_notifier_test');
    store = await SessionStore.open(directory: dir.path);
    runStore = await StoryRunStore.open(directory: dir.path);
    api = FakeStoryApi()..reply = (w, k) async => splitOf25(w, k);
    started = [];
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runStore),
      storyApiServiceProvider.overrideWithValue(api),
      storyRunStartHookProvider.overrideWithValue(
          (sessionId, group) async => started.add('$sessionId:${group.id}')),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Makes [s] the current session, as the launch rule would.
  Future<Session> makeCurrent(Session s) async {
    s.lastLocalModifiedAt = DateTime.now();
    await store.put(s);
    await store.setCurrentSessionId(s.sessionId);
    return (await container.read(wordInputNotifierProvider.future));
  }

  WordGroupsNotifier current() =>
      container.read(wordGroupsNotifierProvider(null).notifier);
  WordGroupsState stateOf([String? id]) =>
      container.read(wordGroupsNotifierProvider(id));

  test('a session of 19 words or fewer becomes one "All words" group, with no call (AC-02)',
      () async {
    await makeCurrent(sessionOf(10));

    await current().ensureGrouped();

    expect(api.asked, isEmpty);
    expect(stateOf().status, isA<GroupingIdle>());
    expect(stateOf().groups.map((g) => g.name), [allWordsName]);
    expect(stateOf().groups.single.rowIds, ids(1, 10));
    final saved = await store.byId(
        (await container.read(wordInputNotifierProvider.future)).sessionId);
    expect(saved!.groups.single.name, allWordsName);
    expect(saved.groupedWordsKey, isNotEmpty);
  });

  test('grouping runs once per change and not again when nothing changed (AC-03)',
      () async {
    final cur = await makeCurrent(sessionOf(25));

    await current().ensureGrouped();
    expect(api.asked, hasLength(1));
    expect(api.asked.single, hasLength(25));
    expect(stateOf().groups.map((g) => g.name), ['Food', 'Travel']);

    await current().ensureGrouped();
    expect(api.asked, hasLength(1), reason: 'unchanged words must not group again');

    // A translation edit is not a change.
    cur.words[0].translation = 'інший';
    await current().ensureGrouped();
    expect(api.asked, hasLength(1));

    // An added English word is.
    cur.words = [...cur.words, row('r26', 'w26')];
    api.reply = (w, k) async => [
          for (final g in k) SplitGroup(id: g.id, name: g.name, rowIds: [...g.rowIds, if (g.name == 'Food') 'r26'])
        ];
    await current().ensureGrouped();
    expect(api.asked, hasLength(2));
    expect(stateOf().groups.map((g) => g.name), ['Food', 'Travel']);
    expect(stateOf().groups.first.rowIds, contains('r26'));
  });

  test('a failed call gives the failed state, and Try again asks once more (AC-04)',
      () async {
    await makeCurrent(sessionOf(25));
    api.reply = (w, k) async =>
        throw StoryApiException(StoryApiError.groupingFailed, 'status 502');

    await current().ensureGrouped();
    expect(stateOf().status, isA<GroupingFailed>());
    expect(stateOf().groups, isEmpty);
    expect(started, isEmpty);

    api.reply = (w, k) async => splitOf25(w, k);
    await current().ensureGrouped();
    expect(api.asked, hasLength(2));
    expect(stateOf().status, isA<GroupingIdle>());
    expect(stateOf().groups, hasLength(2));
  });

  test('an invalid split gives the failed state and saves nothing (AC-04)', () async {
    final cur = await makeCurrent(sessionOf(25));
    // r25 is left out.
    api.reply = (w, k) async => [
          SplitGroup(name: 'Food', rowIds: ids(1, 13)),
          SplitGroup(name: 'Travel', rowIds: ids(14, 24)),
        ];

    await current().ensureGrouped();

    expect(stateOf().status, isA<GroupingFailed>());
    final saved = await store.byId(cur.sessionId);
    expect(saved!.groups, isEmpty);
    expect(saved.groupedWordsKey, isNull);
  });

  test('words with no room wait: waiting(N) (AC-05)', () async {
    // A story group of 19 words is full; 3 added words cannot make a group.
    final s = sessionOf(22);
    s.groups = [
      WordGroup()
        ..id = 'g1'
        ..name = 'Story'
        ..rowIds = ids(1, 19)
        ..storyRunId = 'run1'
        ..storyWords = [for (var i = 1; i <= 19; i++) 'wr$i']
    ];
    s.selectedGroupId = 'g1';
    await makeCurrent(s);

    await current().ensureGrouped();

    expect(api.asked, isEmpty);
    final status = stateOf().status;
    expect(status, isA<GroupingWaiting>());
    expect((status as GroupingWaiting).count, 3);
    expect(stateOf().groups.map((g) => g.id), ['g1']);
  });

  test('a small session with a story group gets its own "New words" group (AC-02b)',
      () async {
    final s = sessionOf(12);
    s.groups = [
      WordGroup()
        ..id = 'g1'
        ..name = allWordsName
        ..rowIds = ids(1, 10)
        ..storyRunId = 'run1'
        ..storyWords = [for (var i = 1; i <= 10; i++) 'wr$i']
    ];
    await makeCurrent(s);

    await current().ensureGrouped();

    expect(stateOf().groups.map((g) => g.name), [allWordsName, newWordsName]);
    expect(stateOf().groups.last.rowIds, ['r11', 'r12']);
    expect(stateOf().groups.first.rowIds, ids(1, 10));
  });

  test('the story group of a run in progress keeps its words (AC-05)', () async {
    final s = sessionOf(25);
    s.groups = [
      WordGroup()
        ..id = 'g1'
        ..name = 'Going'
        ..rowIds = ids(1, 10),
    ];
    final cur = await makeCurrent(s);
    api.reply = (w, k) async => [
          SplitGroup(name: 'Rest A', rowIds: ids(11, 18)),
          SplitGroup(name: 'Rest B', rowIds: ids(19, 25)),
        ];
    await runStore.put(StoryRun()
      ..runId = 'run-going'
      ..sessionId = cur.sessionId
      ..groupId = 'g1'
      ..groupName = 'Going'
      ..startedAt = DateTime.now());

    await current().ensureGrouped();

    expect(api.asked.single.map((w) => w.rowId), isNot(contains('r1')));
    expect(stateOf().groups.first.id, 'g1');
    expect(stateOf().groups.first.rowIds, ids(1, 10));
  });

  test('selection persists and survives a new notifier (AC-01)', () async {
    final cur = await makeCurrent(sessionOf(25));
    await current().ensureGrouped();
    final second = stateOf().groups[1].id;
    expect(stateOf().selectedGroupId, stateOf().groups.first.id);

    await current().select(second);

    expect(stateOf().selectedGroupId, second);
    final saved = await store.byId(cur.sessionId);
    expect(saved!.selectedGroupId, second);

    container.invalidate(wordGroupsNotifierProvider(null));
    await current().ensureGrouped();
    expect(stateOf().selectedGroupId, second);
    expect(api.asked, hasLength(1));
  });

  test('selecting an unknown group changes nothing', () async {
    await makeCurrent(sessionOf(25));
    await current().ensureGrouped();
    final first = stateOf().selectedGroupId;

    await current().select('nope');

    expect(stateOf().selectedGroupId, first);
  });

  test('a selected group that is gone falls back to the first (AC-01)', () async {
    final s = sessionOf(10);
    s.selectedGroupId = 'gone';
    await makeCurrent(s);

    await current().ensureGrouped();

    expect(stateOf().selectedGroupId, stateOf().groups.first.id);
  });

  test('the selected group with no story and no run asks the tracker hook (AC-06 seam)',
      () async {
    final cur = await makeCurrent(sessionOf(25));
    await current().ensureGrouped();
    final first = stateOf().groups.first.id;
    expect(started, ['${cur.sessionId}:$first']);

    final second = stateOf().groups[1].id;
    await current().select(second);
    expect(started.last, '${cur.sessionId}:$second');
  });

  test('a selected group that has a story does not start a run', () async {
    final s = sessionOf(10);
    s.groups = [
      WordGroup()
        ..id = 'g1'
        ..name = allWordsName
        ..rowIds = ids(1, 10)
        ..storyRunId = 'run1'
        ..storyWords = [for (var i = 1; i <= 10; i++) 'wr$i']
    ];
    s.selectedGroupId = 'g1';
    await makeCurrent(s);

    await current().ensureGrouped();

    expect(started, isEmpty);
  });

  test('a History session is grouped and saved without touching the current one (AC-11)',
      () async {
    final cur = await makeCurrent(sessionOf(10));
    final history = sessionOf(25, prefix: 'h');
    history.lastLocalModifiedAt = DateTime.now().subtract(const Duration(days: 3));
    await store.put(history);
    api.reply = (w, k) async => [
          SplitGroup(name: 'Food', rowIds: ids(1, 13, prefix: 'h')),
          SplitGroup(name: 'Travel', rowIds: ids(14, 25, prefix: 'h')),
        ];

    final notifier = container.read(wordGroupsNotifierProvider(history.sessionId).notifier);
    await notifier.ensureGrouped();
    await notifier.select(stateOf(history.sessionId).groups[1].id);

    final savedHistory = await store.byId(history.sessionId);
    expect(savedHistory!.groups.map((g) => g.name), ['Food', 'Travel']);
    expect(savedHistory.selectedGroupId, savedHistory.groups[1].id);
    expect(started.every((s) => s.startsWith('${history.sessionId}:')), isTrue);

    final savedCurrent = await store.byId(cur.sessionId);
    expect(savedCurrent!.groups, isEmpty);
    expect(savedCurrent.groupedWordsKey, isNull);
    expect(await store.currentSessionId(), cur.sessionId);
    expect(container.read(wordInputNotifierProvider).value!.sessionId, cur.sessionId);
    expect(container.read(wordInputNotifierProvider).value!.groups, isEmpty);
  });
}
