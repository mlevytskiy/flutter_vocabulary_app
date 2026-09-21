import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// The four launch cases from `docs/tasks/task-03-words-survive-restart.md`.
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
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('launch_rule_test');
    store = await SessionStore.open(directory: dir.path);
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<Session> launch() =>
      container.read(wordInputNotifierProvider.future);

  String? restorableId() => container
      .read(wordInputNotifierProvider.notifier)
      .restorableSessionId;

  Future<Session> seed({
    required Duration ago,
    List<WordPair>? words,
    bool makeCurrent = true,
  }) async {
    final at = DateTime.now().subtract(ago);
    final s = Session.create()
      ..updatedAt = at
      ..lastLocalModifiedAt = at
      ..words = words ?? [WordPair(word: 'apple', translation: 'яблуко')];
    await store.put(s);
    if (makeCurrent) await store.setCurrentSessionId(s.sessionId);
    return s;
  }

  test('case 1 — nothing stored: new session, one blank row, no snackbar',
      () async {
    final session = await launch();

    expect(session.words.length, 1);
    expect(session.words.single.isEmpty, isTrue);
    expect(restorableId(), isNull);
    expect(await store.currentSessionId(), session.sessionId);
  });

  test('case 2 — the previous session never got a word: reuse it, any age',
      () async {
    final prev = await seed(ago: const Duration(days: 3), words: [WordPair()]);

    final session = await launch();

    expect(session.sessionId, prev.sessionId,
        reason: 'launch-and-do-nothing must not leave empty sessions behind');
    expect(session.words.length, 1);
    expect(restorableId(), isNull);
  });

  test('case 3 — touched under 5 minutes ago: carry on in it, no snackbar',
      () async {
    final prev = await seed(ago: const Duration(minutes: 4, seconds: 30));

    final session = await launch();

    expect(session.sessionId, prev.sessionId);
    expect(session.words.map((w) => w.word), ['apple']);
    expect(restorableId(), isNull);
  });

  test('case 3 — the per-row extras come back with the words', () async {
    final prev = await seed(
      ago: const Duration(seconds: 5),
      words: [
        WordPair(
          word: 'apple',
          translation: 'яблуко',
          hasTranslationOptions: true,
          wordMarkedFilled: true,
          translationMarkedFilled: true,
          translationOptionsJson: '{"text":"яблуко"}',
        ),
      ],
    );

    final session = await launch();

    expect(session.sessionId, prev.sessionId);
    final row = session.words.single;
    expect(row.hasTranslationOptions, isTrue);
    expect(row.wordMarkedFilled, isTrue);
    expect(row.translationMarkedFilled, isTrue);
    expect(row.translationOptions?.text, 'яблуко');
  });

  test('case 4 — gone cold: a new session is current, the old one is offered',
      () async {
    final prev = await seed(ago: const Duration(minutes: 6));

    final session = await launch();

    expect(session.sessionId, isNot(prev.sessionId));
    expect(session.words.single.isEmpty, isTrue);
    expect(restorableId(), prev.sessionId);
    expect(await store.currentSessionId(), session.sessionId);
    expect((await store.byId(prev.sessionId))!.words.length, 1,
        reason: 'the old session stays in the store either way');
  });

  test('case 4 — RESTORE brings the old session back and leaves no empty one',
      () async {
    final prev = await seed(ago: const Duration(minutes: 6));
    final fresh = await launch();

    await container.read(wordInputNotifierProvider.notifier).restorePrevious();

    final now = container.read(wordInputNotifierProvider).value!;
    expect(now.sessionId, prev.sessionId);
    expect(now.words.map((w) => w.word), ['apple']);
    expect(await store.currentSessionId(), prev.sessionId);
    expect(await store.byId(fresh.sessionId), isNull,
        reason: 'the empty session created at launch is deleted');
    expect(
      now.lastLocalModifiedAt.isAfter(DateTime.now().subtract(
        const Duration(minutes: 1),
      )),
      isTrue,
      reason: 'restoring counts as this device touching the session',
    );
    expect(restorableId(), isNull);
  });

  test('the first edit takes RESTORE off the table', () async {
    await seed(ago: const Duration(minutes: 6));
    await launch();
    expect(restorableId(), isNotNull);

    container.read(wordInputNotifierProvider.notifier).updateAt(0, word: 'a');
    expect(restorableId(), isNull);

    // ...and RESTORE after that is a no-op rather than a data loss.
    await container.read(wordInputNotifierProvider.notifier).restorePrevious();
    expect(container.read(wordInputNotifierProvider).value!.words.single.word,
        'a');
  });

  test('a dangling current_session_id falls back to the newest session',
      () async {
    final prev = await seed(
        ago: const Duration(seconds: 5), makeCurrent: false);
    await store.setCurrentSessionId('gone');

    final session = await launch();

    expect(session.sessionId, prev.sessionId);
  });

  // The regression that hid the snackbar on a real device: the screen calls
  // flush() on every AppLifecycleState.paused, so backgrounding or force-quitting
  // the app must not count as "this device touched the session".
  test('flush() without an edit does not restart the session clock', () async {
    final prev = await seed(ago: const Duration(minutes: 3));
    final session = await launch();
    expect(session.sessionId, prev.sessionId, reason: 'case 3 sanity');

    await container.read(wordInputNotifierProvider.notifier).flush();

    final stored = await store.byId(prev.sessionId);
    expect(
      DateTime.now().difference(stored!.lastLocalModifiedAt),
      greaterThan(const Duration(minutes: 2)),
      reason: 'a save with nothing to save must not look like an edit',
    );
  });

  test('backgrounding a cold session still leaves it restorable next launch',
      () async {
    // Type something, then leave it alone for longer than the idle window and
    // background the app on the way out — exactly the device walkthrough.
    await launch();
    final first = container.read(wordInputNotifierProvider.notifier);
    first.updateAt(0, word: 'apple', translation: 'яблуко');
    await first.flush();
    final id = container.read(wordInputNotifierProvider).value!.sessionId;

    // Age it the way wall-clock time would.
    final stale = await store.byId(id);
    stale!.lastLocalModifiedAt =
        DateTime.now().subtract(const Duration(minutes: 6));
    stale.updatedAt = stale.lastLocalModifiedAt;
    await store.put(stale);

    // The force-quit: paused -> flush() with no pending edit.
    await first.flush();

    // Relaunch.
    container.dispose();
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
    ]);
    final fresh = await launch();

    expect(fresh.sessionId, isNot(id));
    expect(restorableId(), id, reason: 'the snackbar has something to offer');
  });

  test('updateAt carries the extras through to the store', () async {
    await launch();
    final notifier = container.read(wordInputNotifierProvider.notifier);
    notifier.updateAt(0,
        word: 'apple',
        translation: 'яблуко',
        hasTranslationOptions: true,
        wordMarkedFilled: true,
        translationMarkedFilled: true);
    await notifier.flush();

    final stored = await store
        .byId(container.read(wordInputNotifierProvider).value!.sessionId);
    final row = stored!.words.single;
    expect(row.word, 'apple');
    expect(row.hasTranslationOptions, isTrue);
    expect(row.wordMarkedFilled, isTrue);
    expect(row.translationMarkedFilled, isTrue);
  });
}
