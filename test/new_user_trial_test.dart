import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/app.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/new_user_trial.dart';
import 'package:flutter_vocabulary_app/features/app_settings/app_settings_screen.dart';

/// new-user-trial: the data goes aside, the app is empty, a restore brings
/// it back and drops what was entered in between.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // As in collection_store_test: lift the test HttpOverrides for the
    // one-off IsarCore download.
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
  });

  late Directory root;
  late Directory documents;
  late NewUserTrial trial;
  var closed = 0;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('trial');
    documents = await Directory('${root.path}/docs').create();
    final support = await Directory('${root.path}/support').create();
    closed = 0;
    trial = NewUserTrial(
      documents: () async => documents,
      support: () async => support,
      closeDatabase: () async => closed++,
    );
    SharedPreferences.setMockInitialValues({
      'app_theme': 'matcha',
      'current_session_id': 'abc',
      'count': 3,
      'ratio': 0.5,
      'on': true,
      'list': ['a', 'b'],
    });
    await File('${documents.path}/vocab.isar').writeAsString('my db');
    await Directory('${documents.path}/source_photos').create();
    await File('${documents.path}/source_photos/p.jpg').writeAsString('jpg');
  });

  tearDown(() => root.delete(recursive: true));

  test('no backup, no trial', () async {
    expect(await trial.backupTakenAt(), isNull);
  });

  test('start puts files and preferences aside and leaves the app empty',
      () async {
    await trial.start();
    expect(closed, 1);
    expect(documents.listSync(), isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    expect(await trial.backupTakenAt(), isNotNull);
  });

  test('a second start keeps the first backup', () async {
    await trial.start();
    await File('${documents.path}/vocab.isar').writeAsString('trial db');
    await trial.start();
    await trial.restore();
    expect(await File('${documents.path}/vocab.isar').readAsString(), 'my db');
  });

  test('restore deletes the trial data and brings everything back', () async {
    await trial.start();
    await File('${documents.path}/vocab.isar').writeAsString('trial db');
    await File('${documents.path}/new.txt').writeAsString('new');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', 'aurora');
    await prefs.setString('trial_only', 'x');

    await trial.restore();

    expect(closed, 2);
    expect(await File('${documents.path}/vocab.isar').readAsString(), 'my db');
    expect(
        await File('${documents.path}/source_photos/p.jpg').readAsString(), 'jpg');
    expect(File('${documents.path}/new.txt').existsSync(), isFalse);
    expect(prefs.getString('app_theme'), 'matcha');
    expect(prefs.getString('current_session_id'), 'abc');
    expect(prefs.getInt('count'), 3);
    expect(prefs.getDouble('ratio'), 0.5);
    expect(prefs.getBool('on'), isTrue);
    expect(prefs.getStringList('list'), ['a', 'b']);
    expect(prefs.containsKey('trial_only'), isFalse);
    expect(await trial.backupTakenAt(), isNull);
  });

  test('restore without a backup changes nothing', () async {
    await trial.restore();
    expect(closed, 0);
    expect(await File('${documents.path}/vocab.isar').readAsString(), 'my db');
  });

  Future<void> pumpSettings(WidgetTester tester, DateTime? takenAt) async {
    // Tall enough that the section below the theme gallery is built.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [newUserBackupProvider.overrideWith((ref) async => takenAt)],
      child: const MaterialApp(home: AppSettingsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('App settings offers to start as a new user', (tester) async {
    await pumpSettings(tester, null);
    expect(find.byKey(AppSettingsScreen.startNewUserKey), findsOneWidget);
    expect(find.byKey(AppSettingsScreen.restoreKey), findsNothing);
    await tester.ensureVisible(find.byKey(AppSettingsScreen.startNewUserKey));
    await tester.tap(find.byKey(AppSettingsScreen.startNewUserKey));
    await tester.pumpAndSettle();
    expect(find.text('Start as a new user?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Start as a new user?'), findsNothing);
  });

  testWidgets('during a trial App settings offers to restore', (tester) async {
    await pumpSettings(tester, DateTime(2026, 10, 17, 14, 5));
    expect(find.byKey(AppSettingsScreen.restoreKey), findsOneWidget);
    expect(find.byKey(AppSettingsScreen.startNewUserKey), findsNothing);
    expect(find.textContaining('Oct 17, 2026'), findsOneWidget);
    await tester.ensureVisible(find.byKey(AppSettingsScreen.restoreKey));
    await tester.tap(find.byKey(AppSettingsScreen.restoreKey));
    await tester.pumpAndSettle();
    expect(find.text('Restore your data?'), findsOneWidget);
    expect(find.text('Delete and restore'), findsOneWidget);
  });

  test('the real database closes, starts empty and comes back', () async {
    await File('${documents.path}/vocab.isar').delete();
    var store = await CollectionStore.open(directory: documents.path);
    final mine = await store.create(name: 'Trip to London', keep: true);
    final real = NewUserTrial(
      documents: () async => documents,
      support: () async => Directory('${root.path}/support'),
    );

    await real.start();
    expect(Isar.getInstance('vocab'), isNull);
    store = await CollectionStore.open(directory: documents.path);
    expect(await store.allIds(), isNot(contains(mine.collectionId)));
    await store.create(name: 'Trial', keep: true);

    await real.restore();
    store = await CollectionStore.open(directory: documents.path);
    final ids = await store.allIds();
    expect(ids, contains(mine.collectionId));
    expect(ids, hasLength(1));
    await Isar.getInstance('vocab')?.close();
  });

  Future<void> pumpFrame(WidgetTester tester, DateTime? takenAt) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [newUserBackupProvider.overrideWith((ref) async => takenAt)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24)),
          child: TrialFrame(child: child!),
        ),
        home: Scaffold(appBar: AppBar(title: const Text('Main'))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a red line runs above the top bar during a trial',
      (tester) async {
    await pumpFrame(tester, DateTime(2026, 10, 17));
    final line = find.byKey(TrialFrame.lineKey);
    expect(line, findsOneWidget);
    expect(tester.getTopLeft(line).dy, 24);
    expect(tester.getSize(line).width, tester.view.physicalSize.width / tester.view.devicePixelRatio);
    expect(tester.widget<ColoredBox>(line).color, TrialFrame.lineColor);
  });

  testWidgets('no red line without a trial', (tester) async {
    await pumpFrame(tester, null);
    expect(find.byKey(TrialFrame.lineKey), findsNothing);
  });
}
