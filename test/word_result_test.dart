import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';

/// learn-kit S-22: the Step 3 word results on a session (AC-35 – AC-38).
/// One Isar store for the whole file (docs/testing.md rule 4).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late SessionStore store;

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('word_result_test');
    store = await SessionStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final t0 = DateTime.utc(2026, 10, 14, 12);

  Session session(String id) => Session.create()
    ..sessionId = id
    ..updatedAt = t0
    ..lastLocalModifiedAt = t0
    ..words = [WordPair(word: 'walk', translation: 'гуляти', rowId: 'r1')];

  WordResult result(String rowId, WordResultLabel label, DateTime at,
          {String exercise = 'quiz'}) =>
      WordResult()
        ..rowId = rowId
        ..exerciseId = exercise
        ..label = label
        ..at = at;

  test('the label keeps its stored order: known first, then repeat', () {
    expect(WordResultLabel.values, [WordResultLabel.known, WordResultLabel.repeat]);
  });

  test('AC-38: a session has no results until one is written; JSON round-trips them', () {
    final s = session('json');
    expect(s.results, isEmpty);
    s.results = [result('r1', WordResultLabel.repeat, t0)];
    final back = Session.fromJson(s.toJson());
    expect(back.results.single.rowId, 'r1');
    expect(back.results.single.exerciseId, 'quiz');
    expect(back.results.single.label, WordResultLabel.repeat);
    expect(back.results.single.at, t0);
    // JSON from before learn-kit has no results.
    final old = s.toJson()..remove('results');
    expect(Session.fromJson(old).results, isEmpty);
  });

  test('AC-35, AC-37: appendResult saves at once and moves neither time', () async {
    await store.put(session('append'));
    expect(await store.appendResult('append', result('r1', WordResultLabel.known, t0)), isTrue);
    await store.appendResult('append', result('r1', WordResultLabel.repeat, t0.add(const Duration(minutes: 1))));
    final read = (await store.byId('append'))!;
    expect(read.results.map((r) => r.label), [WordResultLabel.known, WordResultLabel.repeat]);
    expect(read.updatedAt.isAtSameMomentAs(t0), isTrue);
    expect(read.lastLocalModifiedAt.isAtSameMomentAs(t0), isTrue);
  });

  test('appendResult on an unknown session writes nothing and says so', () async {
    expect(await store.appendResult('nope', result('r1', WordResultLabel.known, t0)), isFalse);
    expect(await store.byId('nope'), isNull);
  });

  test('a later put of a stale session object keeps the stored results', () async {
    final s = session('stale');
    await store.put(s);
    await store.appendResult('stale', result('r1', WordResultLabel.known, t0));
    // The words notifier still holds `s`, which never saw the result.
    s.words.add(WordPair(word: 'run', translation: 'бігти', rowId: 'r2'));
    await store.put(s);
    final read = (await store.byId('stale'))!;
    expect(read.words.length, 2);
    expect(read.results.single.rowId, 'r1');
  });

  test('AC-38: the 2001st result drops the oldest', () async {
    final s = session('cap')
      ..results = [
        for (var i = 0; i < Session.maxResults; i++)
          result('r$i', WordResultLabel.known, t0.add(Duration(seconds: i))),
      ];
    await store.put(s);
    expect((await store.byId('cap'))!.results.length, Session.maxResults);
    await store.appendResult('cap', result('new', WordResultLabel.repeat, t0.add(const Duration(days: 1))));
    final read = (await store.byId('cap'))!;
    expect(read.results.length, Session.maxResults);
    expect(read.results.first.rowId, 'r1');
    expect(read.results.last.rowId, 'new');
  });

  test('AC-37: results never reach a word row', () {
    final s = session('rows')..results = [result('r1', WordResultLabel.repeat, t0)];
    expect(s.words.single.toJson().toString(), isNot(contains('repeat')));
  });
}
