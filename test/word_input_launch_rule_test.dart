import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
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
  late CollectionStore store;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('launch_rule_test');
    store = await CollectionStore.open(directory: dir.path);
    container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<WordCollection> launch() =>
      container.read(wordInputNotifierProvider.future);

  String? restorableId() => container
      .read(wordInputNotifierProvider.notifier)
      .restorableCollectionId;

  Future<WordCollection> seed({
    required Duration ago,
    List<WordPair>? words,
    bool makeCurrent = true,
  }) async {
    final at = DateTime.now().subtract(ago);
    final s = WordCollection.create()
      ..updatedAt = at
      ..lastLocalModifiedAt = at
      ..words = words ?? [WordPair(word: 'apple', translation: 'яблуко')];
    await store.put(s);
    if (makeCurrent) await store.setCurrentCollectionId(s.collectionId);
    return s;
  }

  test('case 1 — nothing stored: new session, one blank row, no snackbar',
      () async {
    final collection = await launch();

    expect(collection.words.length, 1);
    expect(collection.words.single.isEmpty, isTrue);
    expect(restorableId(), isNull);
    expect(await store.currentCollectionId(), collection.collectionId);
  });

  test('case 2 — the previous session never got a word: reuse it, any age',
      () async {
    final prev = await seed(ago: const Duration(days: 3), words: [WordPair()]);

    final collection = await launch();

    expect(collection.collectionId, prev.collectionId,
        reason: 'launch-and-do-nothing must not leave empty sessions behind');
    expect(collection.words.length, 1);
    expect(restorableId(), isNull);
  });

  test('case 3 — touched under 5 minutes ago: carry on in it, no snackbar',
      () async {
    final prev = await seed(ago: const Duration(minutes: 4, seconds: 30));

    final collection = await launch();

    expect(collection.collectionId, prev.collectionId);
    expect(collection.words.map((w) => w.word), ['apple']);
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

    final collection = await launch();

    expect(collection.collectionId, prev.collectionId);
    final row = collection.words.single;
    expect(row.hasTranslationOptions, isTrue);
    expect(row.wordMarkedFilled, isTrue);
    expect(row.translationMarkedFilled, isTrue);
    expect(row.translationOptions?.text, 'яблуко');
  });

  test('case 4 — gone cold: a new session is current, the old one is offered',
      () async {
    final prev = await seed(ago: const Duration(minutes: 6));

    final collection = await launch();

    expect(collection.collectionId, isNot(prev.collectionId));
    expect(collection.words.single.isEmpty, isTrue);
    expect(restorableId(), prev.collectionId);
    expect(await store.currentCollectionId(), collection.collectionId);
    expect((await store.byId(prev.collectionId))!.words.length, 1,
        reason: 'the old session stays in the store either way');
  });

  test('case 4 — RESTORE brings the old session back and leaves no empty one',
      () async {
    final prev = await seed(ago: const Duration(minutes: 6));
    final fresh = await launch();

    await container.read(wordInputNotifierProvider.notifier).restorePrevious();

    final now = container.read(wordInputNotifierProvider).value!;
    expect(now.collectionId, prev.collectionId);
    expect(now.words.map((w) => w.word), ['apple']);
    expect(await store.currentCollectionId(), prev.collectionId);
    expect(await store.byId(fresh.collectionId), isNull,
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
    await store.setCurrentCollectionId('gone');

    final collection = await launch();

    expect(collection.collectionId, prev.collectionId);
  });

  // The regression that hid the snackbar on a real device: the screen calls
  // flush() on every AppLifecycleState.paused, so backgrounding or force-quitting
  // the app must not count as "this device touched the session".
  test('flush() without an edit does not restart the session clock', () async {
    final prev = await seed(ago: const Duration(minutes: 3));
    final collection = await launch();
    expect(collection.collectionId, prev.collectionId, reason: 'case 3 sanity');

    await container.read(wordInputNotifierProvider.notifier).flush();

    final stored = await store.byId(prev.collectionId);
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
    final id = container.read(wordInputNotifierProvider).value!.collectionId;

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
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
    final fresh = await launch();

    expect(fresh.collectionId, isNot(id));
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
        .byId(container.read(wordInputNotifierProvider).value!.collectionId);
    final row = stored!.words.single;
    expect(row.word, 'apple');
    expect(row.hasTranslationOptions, isTrue);
    expect(row.wordMarkedFilled, isTrue);
    expect(row.translationMarkedFilled, isTrue);
  });

  // edit-session-from-history T3 (ADR-0002, AC-09): a session picked from
  // History counts as warm for the idle window after the pick.
  group('a recent pick', () {
    Future<void> relaunch() async {
      container.dispose();
      container = ProviderContainer(overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
      ]);
    }

    test('picked 2 minutes ago reopens with no RESTORE, twice in a row',
        () async {
      final prev = await seed(ago: const Duration(days: 7));
      await store.setSwitched(
          prev.collectionId, DateTime.now().subtract(const Duration(minutes: 2)));

      var collection = await launch();
      expect(collection.collectionId, prev.collectionId);
      expect(restorableId(), isNull);

      await relaunch();
      collection = await launch();
      expect(collection.collectionId, prev.collectionId);
      expect(restorableId(), isNull);
      expect(await store.switchedAt(prev.collectionId), isNotNull,
          reason: 'the pointer re-save leaves the pick record alone');
    });

    test('picked 6 minutes ago: a new session and the RESTORE offer',
        () async {
      final prev = await seed(ago: const Duration(days: 7));
      await store.setSwitched(
          prev.collectionId, DateTime.now().subtract(const Duration(minutes: 6)));

      final collection = await launch();

      expect(collection.collectionId, isNot(prev.collectionId));
      expect(restorableId(), prev.collectionId);
    });

    test('a pick record for another session is ignored', () async {
      final prev = await seed(ago: const Duration(days: 7));
      await store.setSwitched('other', DateTime.now());

      final collection = await launch();

      expect(collection.collectionId, isNot(prev.collectionId));
      expect(restorableId(), prev.collectionId);
    });

    test('a dangling pointer falling back to the newest ignores the record',
        () async {
      final prev =
          await seed(ago: const Duration(days: 7), makeCurrent: false);
      await store.setCurrentCollectionId('gone');
      await store.setSwitched(prev.collectionId, DateTime.now());

      final collection = await launch();

      expect(collection.collectionId, isNot(prev.collectionId));
      expect(restorableId(), prev.collectionId);
    });
  });

  // Owner, 2026-10-16: having a session with words open counts as touching
  // it; the main screen records it every 15 s (markSeen).
  group('seen open', () {
    test('seen 2 minutes ago, edited a week ago: carry on, no RESTORE',
        () async {
      final prev = await seed(ago: const Duration(days: 7));
      await store.setSeen(
          prev.collectionId, DateTime.now().subtract(const Duration(minutes: 2)));

      final collection = await launch();

      expect(collection.collectionId, prev.collectionId);
      expect(restorableId(), isNull);
    });

    test('seen 6 minutes ago: a new session and the RESTORE offer', () async {
      final prev = await seed(ago: const Duration(days: 7));
      await store.setSeen(
          prev.collectionId, DateTime.now().subtract(const Duration(minutes: 6)));

      final collection = await launch();

      expect(collection.collectionId, isNot(prev.collectionId));
      expect(restorableId(), prev.collectionId);
    });

    test('a seen record for another session is ignored', () async {
      final prev = await seed(ago: const Duration(days: 7));
      await store.setSeen('other', DateTime.now());

      final collection = await launch();

      expect(collection.collectionId, isNot(prev.collectionId));
      expect(restorableId(), prev.collectionId);
    });

    test('markSeen records a session with words, and leaves its times alone',
        () async {
      final prev = await seed(ago: const Duration(minutes: 1));
      final collection = await launch();
      expect(collection.collectionId, prev.collectionId);

      await container.read(wordInputNotifierProvider.notifier).markSeen();

      final seen = await store.seenAt(prev.collectionId);
      expect(seen, isNotNull);
      expect(DateTime.now().difference(seen!), lessThan(const Duration(seconds: 5)));
      final stored = await store.byId(prev.collectionId);
      expect(stored!.lastLocalModifiedAt, prev.lastLocalModifiedAt,
          reason: 'being open is not an edit');
    });

    test('markSeen does not record a session with no word', () async {
      final collection = await launch(); // case 1: a new, empty session

      await container.read(wordInputNotifierProvider.notifier).markSeen();

      expect(await store.seenAt(collection.collectionId), isNull);
    });
  });
}
