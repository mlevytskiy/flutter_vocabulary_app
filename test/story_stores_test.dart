import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_picture_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';

/// Hermetic: a throwaway directory per test, no network, no device. The
/// picture compressor is a fake (the plugin has no host in a unit test).
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
  late SessionStore sessions;
  late StoryRunStore runs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('story_stores_test');
    sessions = await SessionStore.open(directory: dir.path);
    runs = await StoryRunStore.open(directory: dir.path);
  });

  tearDown(() async {
    await sessions.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  StoryRun run(String id, DateTime at,
          {bool collected = false, String outcome = 'running'}) =>
      StoryRun()
        ..runId = id
        ..sessionId = 's1'
        ..groupId = 'g1'
        ..groupName = 'Group $id'
        ..words = ['apple', 'pear']
        ..startedAt = at
        ..models = ['a', 'b', 'c']
        ..outcome = outcome
        ..collected = collected
        ..steps = [
          StoryStep()
            ..role = 'story'
            ..modelId = 'a'
            ..modelName = 'A'
            ..outcome = 'done'
            ..text = 'Once an apple…'
            ..missedWords = ['pear']
            ..priceUsd = 0.0123
            ..priceEstimated = true
            ..ms = 4200,
        ];

  group('StoryRunStore', () {
    // AC-07, AC-14
    test('a run round-trips with its steps', () async {
      await runs.put(run('r1', DateTime(2026, 10, 1)));
      final back = await runs.byId('r1');
      expect(back, isNotNull);
      expect(back!.groupName, 'Group r1');
      expect(back.words, ['apple', 'pear']);
      expect(back.models, ['a', 'b', 'c']);
      expect(back.steps.single.text, 'Once an apple…');
      expect(back.steps.single.missedWords, ['pear']);
      expect(back.steps.single.priceUsd, 0.0123);
      expect(back.steps.single.priceEstimated, isTrue);
      expect(back.steps.single.ms, 4200);
      expect(await runs.byId('nope'), isNull);
    });

    // AC-14
    test('lists newest first', () async {
      await runs.put(run('old', DateTime(2026, 10, 1)));
      await runs.put(run('new', DateTime(2026, 10, 3)));
      await runs.put(run('mid', DateTime(2026, 10, 2)));
      expect([for (final r in await runs.newestFirst()) r.runId],
          ['new', 'mid', 'old']);
    });

    // AC-07
    test('putting the same run id again updates it, not duplicates it',
        () async {
      await runs.put(run('r1', DateTime(2026, 10, 1)));
      await runs.put(run('r1', DateTime(2026, 10, 1), outcome: 'done'));
      final all = await runs.newestFirst();
      expect(all, hasLength(1));
      expect(all.single.outcome, 'done');
    });

    test('finds the runs not yet collected', () async {
      await runs.put(run('a', DateTime(2026, 10, 1), collected: true));
      await runs.put(run('b', DateTime(2026, 10, 2)));
      await runs.put(run('c', DateTime(2026, 10, 3)));
      expect([for (final r in await runs.uncollected()) r.runId], ['c', 'b']);
    });

    // AC-15: a store never removes a run
    test('a newer run for the same group leaves the older one listed',
        () async {
      await runs.put(run('first', DateTime(2026, 10, 1)));
      await runs.put(run('second', DateTime(2026, 10, 2)));
      expect(await runs.newestFirst(), hasLength(2));
      expect(await runs.byId('first'), isNotNull);
    });

    test('watch emits now and after every put', () async {
      await runs.put(run('r1', DateTime(2026, 10, 1)));
      final seen = <String>[];
      final sub = runs.watch('r1').listen((r) => seen.add(r?.outcome ?? '-'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await runs.put(run('r1', DateTime(2026, 10, 1), outcome: 'done'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      expect(seen.first, 'running');
      expect(seen.last, 'done');
    });

    test('watchNewestFirst emits all runs now and after every put', () async {
      await runs.put(run('a', DateTime(2026, 10, 1)));
      final seen = <List<String>>[];
      final sub = runs.watchNewestFirst().listen(
          (l) => seen.add([for (final r in l) r.runId]));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await runs.put(run('b', DateTime(2026, 10, 2)));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      expect(seen.first, ['a']);
      expect(seen.last, ['b', 'a']);
    });

    test('shares the database with the session store', () async {
      expect(Isar.getInstance('vocab'), isNotNull);
    });
  });

  group('StoryPictureStore', () {
    const limit = 3 * 1024 * 1024;

    // A fake compressor: the output shrinks as quality drops.
    Future<Uint8List?> shrinking(Uint8List bytes, int quality) async =>
        Uint8List(bytes.length * quality ~/ 100);

    test('writes a small picture and reads it back', () async {
      final store = StoryPictureStore(
          directory: dir.path, compress: (b, q) async => b);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final path = await store.write('r1', 1, bytes);
      expect(path, isNotNull);
      expect(path!.endsWith('mnemonic_pictures/r1-1.jpg'), isTrue);
      expect(await store.exists('r1', 1), isTrue);
      expect(await store.read('r1', 1), bytes);
      expect(await store.exists('r1', 2), isFalse);
      expect(await store.read('r1', 2), isNull);
    });

    // AC-07 storage NFR
    test('an oversized picture is written at 3 MB or less', () async {
      final store = StoryPictureStore(directory: dir.path, compress: shrinking);
      final path = await store.write('r1', 1, Uint8List(10 * 1024 * 1024));
      expect(path, isNotNull);
      final size = File(path!).lengthSync();
      expect(size, lessThanOrEqualTo(limit));
      expect(size, greaterThan(0));
    });

    test('a picture that cannot get small enough is not written', () async {
      final store = StoryPictureStore(
          directory: dir.path, compress: (b, q) async => b);
      expect(await store.write('r1', 1, Uint8List(limit + 1)), isNull);
      expect(await store.exists('r1', 1), isFalse);
    });

    test('never throws: a failing compressor gives null', () async {
      final store = StoryPictureStore(
          directory: dir.path, compress: (b, q) async => throw Exception('x'));
      expect(await store.write('r1', 1, Uint8List(10)), isNull);
    });

    test('never throws: a bad directory gives null / false', () async {
      final store = StoryPictureStore(
          directory: '${dir.path}/file.txt/nested', compress: (b, q) async => b);
      File('${dir.path}/file.txt').writeAsStringSync('x');
      expect(await store.write('r1', 1, Uint8List(10)), isNull);
      expect(await store.read('r1', 1), isNull);
      expect(await store.exists('r1', 1), isFalse);
    });
  });
}
