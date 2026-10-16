import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/name_dialog.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

import 'seed_collections.dart';

/// collections-screen T14 (SCR-01, SCR-02; AC-01, AC-02, AC-03, AC-05): the
/// main screen's title is the current collection's stored name, with a white
/// pencil button that renames it through the shared NameDialog.
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

  Directory? dir;
  late CollectionStore store;
  tearDownAll(() {
    if (dir != null && dir!.existsSync()) dir!.deleteSync(recursive: true);
  });
  late ProviderContainer container;
  late WordCollection current;

  /// The title follows a store stream that delivers on the real clock: poll
  /// with real time until it reads [text] (3 s at most).
  Future<void> titleBecomes(WidgetTester tester, String text) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump();
      if (find.descendant(of: find.byType(AppBar), matching: find.text(text))
          .evaluate()
          .isNotEmpty) {
        return;
      }
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
  }

  Future<void> pumpMain(WidgetTester tester, {String? name}) async {
    // Speech stops when the session changes or the screen goes.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (_) async => null);
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'both'});
    await tester.runAsync(() async {
      if (dir == null) {
        dir = Directory.systemTemp.createTempSync('main_title_test');
        store = await CollectionStore.open(directory: dir!.path);
      }
      final at = DateTime.now();
      current = WordCollection.create()
        ..name = name
        ..updatedAt = at
        ..lastLocalModifiedAt = at
        ..words = [WordPair(word: 'apple')];
      await seedCollection(store, current);
      await store.setCurrentCollectionId(current.collectionId);
    });
    container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
    ));
    if (name != null) await titleBecomes(tester, name);
  }

  Future<void> tearDownMain(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  Finder title() => find
      .descendant(of: find.byType(AppBar), matching: find.byType(Text))
      .first;
  Finder editButton() => find.byTooltip('Rename collection');
  Finder nameField() => find.descendant(
      of: find.byType(AlertDialog), matching: find.byType(TextField));

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(editButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('SCR-01 default: the title is the stored name, edit button beside Next',
      (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    expect((tester.widget(title()) as Text).data, 'Kitchen words');
    expect(find.text('English Vocabulary'), findsNothing);
    final edit = tester.widget<ElevatedButton>(find.ancestor(
        of: find.byIcon(Icons.edit), matching: find.byType(ElevatedButton)));
    expect(edit.style?.backgroundColor?.resolve({}), Colors.white);
    expect(find.descendant(
        of: find.ancestor(
            of: find.byIcon(Icons.edit), matching: find.byType(ElevatedButton)),
        matching: find.byType(Text)), findsNothing);
    expect(find.text('Next'), findsOneComponent());
    await tearDownMain(tester);
  });

  testWidgets('SCR-01 long name: one line with ellipsis, buttons keep full size',
      (tester) async {
    await pumpMain(tester, name: 'A' * 60);
    final text = tester.widget<Text>(title());
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.ancestor(
        of: find.text('Next'),
        matching: find.byWidgetPredicate((w) => w is ElevatedButton))).width,
        greaterThan(80));
    expect(tester.getSize(find.ancestor(
        of: find.byIcon(Icons.edit), matching: find.byType(ElevatedButton))).width,
        greaterThanOrEqualTo(48));
    expect(tester.getRect(title()).right,
        lessThanOrEqualTo(tester.getRect(editButton()).left));
    await tearDownMain(tester);
  });

  testWidgets('SCR-01 default name: a collection without a name shows its date name',
      (tester) async {
    await pumpMain(tester);
    await tester.pump();
    final expected = defaultCollectionName(
        creationMomentOf(current.collectionId) ?? current.updatedAt);
    expect((tester.widget(title()) as Text).data, expected);
    await tearDownMain(tester);
  });

  testWidgets('SCR-02: edit opens the dialog with the name selected',
      (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    await openDialog(tester);
    expect(find.text('Rename collection'), findsWidgets);
    final field = tester.widget<TextField>(nameField());
    expect(field.controller!.text, 'Kitchen words');
    expect(field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 13));
    await tearDownMain(tester);
  });

  testWidgets('SCR-02 validation: an empty name keeps the dialog open',
      (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    await openDialog(tester);
    await tester.enterText(nameField(), '');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text(nameProblemMessage), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect((tester.widget(title()) as Text).data, 'Kitchen words');
    await tearDownMain(tester);
  });

  testWidgets('SCR-02 success: Save renames through the store and the title follows',
      (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    await openDialog(tester);
    await tester.enterText(nameField(), 'Garden');
    // The store write runs on the real clock, so the tap does too.
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await titleBecomes(tester, 'Garden');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect((tester.widget(title()) as Text).data, 'Garden');
    await tester.runAsync(() async {
      expect((await store.byId(current.collectionId))!.name, 'Garden');
      // The next autosave must not bring the old name back.
      container.read(wordInputNotifierProvider.notifier).addAll([WordPair(word: 'pear')]);
      await container.read(wordInputNotifierProvider.notifier).flush();
      expect((await store.byId(current.collectionId))!.name, 'Garden');
    });
    await tearDownMain(tester);
  });

  testWidgets('SCR-02 cancel: nothing changes', (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    await openDialog(tester);
    await tester.enterText(nameField(), 'Garden');
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect((tester.widget(title()) as Text).data, 'Kitchen words');
    await tester.runAsync(() async {
      expect((await store.byId(current.collectionId))!.name, 'Kitchen words');
    });
    await tearDownMain(tester);
  });
}

Matcher findsOneComponent() => findsOneWidget;
