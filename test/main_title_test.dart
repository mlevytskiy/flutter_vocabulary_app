import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_name.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/name_kind.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/name_dialog.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/collection_title.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words/words_screen.dart';

import 'seed_collections.dart';

/// collections-screen T14 (SCR-01, SCR-02; AC-01, AC-02, AC-03, AC-05): the
/// main screen's title is the current collection's stored name, with a white
/// pencil button that opens the Collection details sheet (collection-tags T10).
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
      if (find
          .descendant(of: find.byType(AppBar), matching: find.text(text))
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
        // A typed name is the learner's; "Vocabulary" is still AI's to give.
        ..nameKind = name == null || name == undefinedCollectionName
            ? NameKind.undefined
            : NameKind.byUser
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
      await container.read(wordsProvider.future);
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordsScreen()),
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
  Finder nameField() => find.byKey(const Key('details-name'));

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(editButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
      'SCR-01 default: the title is the stored name, edit button beside Next',
      (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    expect((tester.widget(title()) as Text).data, 'Kitchen words');
    expect(find.text('English Vocabulary'), findsNothing);
    // A bare icon (no filled circle) right after the title, in the colour
    // the menu button shares.
    final edit = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.edit), matching: find.byType(IconButton)));
    expect(edit.style?.backgroundColor, isNull);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.iconTheme?.color, edit.color);
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.byIcon(Icons.edit), matching: find.byType(IconButton)),
            matching: find.byType(Text)),
        findsNothing);
    expect(find.text('Next'), findsOneComponent());
    await tearDownMain(tester);
  });

  testWidgets(
      'SCR-01 long name: one line with ellipsis, buttons keep full size',
      (tester) async {
    await pumpMain(tester, name: 'A' * 60);
    final text = tester.widget<Text>(title());
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
    expect(
        tester
            .getSize(find.ancestor(
                of: find.text('Next'),
                matching: find.byWidgetPredicate((w) => w is ElevatedButton)))
            .width,
        greaterThan(80));
    expect(
        tester
            .getSize(find.ancestor(
                of: find.byIcon(Icons.edit), matching: find.byType(IconButton)))
            .height,
        greaterThanOrEqualTo(48));
    expect(tester.getRect(title()).right,
        lessThanOrEqualTo(tester.getRect(editButton()).left));
    // The pencil sits right after the title: no hidden tap-target margin.
    expect(
        tester.getRect(find.byIcon(Icons.edit)).left -
            tester.getRect(title()).right,
        lessThanOrEqualTo(8));
    await tearDownMain(tester);
  });

  testWidgets(
      'SCR-01 default name: a collection without a name shows its date name',
      (tester) async {
    await pumpMain(tester);
    await tester.pump();
    final expected = defaultCollectionName(
        creationMomentOf(current.collectionId) ?? current.updatedAt);
    expect((tester.widget(title()) as Text).data, expected);
    await tearDownMain(tester);
  });

  testWidgets(
      'collection-naming: the AI\'s name replaces "Vocabulary" with the reveal',
      (tester) async {
    await pumpMain(tester, name: 'Vocabulary');
    await tester.runAsync(
        () => store.setAutoName(current.collectionId, 'Kitchen Tools'));
    var revealed = false;
    for (var i = 0; i < 60 && !revealed; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      // Mid-reveal the title is single animated letters.
      revealed = find
          .descendant(
              of: find.byType(CollectionTitle), matching: find.byType(Opacity))
          .evaluate()
          .isNotEmpty;
      if (!revealed) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
      }
    }
    expect(revealed, isTrue);
    // The first pump starts the ticker; the reveal runs from there.
    await tester.pump();
    await tester
        .pump(CollectionTitle.duration + const Duration(milliseconds: 50));
    await tester.pump();
    expect((tester.widget(title()) as Text).data, 'Kitchen Tools');
    await tearDownMain(tester);
  });

  testWidgets('SCR-02: edit opens the details sheet with the name filled in',
      (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    await openDialog(tester);
    expect(find.text('Collection details'), findsOneWidget);
    final field = tester.widget<TextField>(nameField());
    expect(field.controller!.text, 'Kitchen words');
    await tearDownMain(tester);
  });

  testWidgets(
      'collection-naming: edit leaves a name nobody gave empty with the AI note',
      (tester) async {
    await pumpMain(tester, name: 'Vocabulary');
    await openDialog(tester);
    expect(tester.widget<TextField>(nameField()).controller!.text, '');
    expect(find.text('Name (optional)'), findsOneWidget);
    expect(find.byKey(const Key('details-ai-name-note')), findsOneWidget);
    expect(
        find.byKey(const Key('details-ai-description-note')), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('details-confirm')))
            .onPressed,
        isNotNull);
    await tearDownMain(tester);
  });

  testWidgets('SCR-02 validation: an empty name keeps the dialog open',
      (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    await openDialog(tester);
    await tester.enterText(nameField(), '');
    await tester.pump();
    expect(find.text(nameProblemMessage), findsOneWidget);
    expect(find.text('Collection details'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('details-confirm')))
            .onPressed,
        isNull);
    expect((tester.widget(title()) as Text).data, 'Kitchen words');
    await tearDownMain(tester);
  });

  testWidgets(
      'SCR-02 success: Save renames through the store and the title follows',
      (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    await openDialog(tester);
    await tester.enterText(nameField(), 'Garden');
    // The store write runs on the real clock, so the tap does too.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('details-confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await titleBecomes(tester, 'Garden');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Collection details'), findsNothing);
    expect((tester.widget(title()) as Text).data, 'Garden');
    await tester.runAsync(() async {
      expect((await store.byId(current.collectionId))!.name, 'Garden');
      // The next autosave must not bring the old name back.
      container
          .read(wordsProvider.notifier)
          .addAll([WordPair(word: 'pear')]);
      await container.read(wordsProvider.notifier).flush();
      expect((await store.byId(current.collectionId))!.name, 'Garden');
    });
    await tearDownMain(tester);
  });

  testWidgets('SCR-02/03 discard: nothing changes', (tester) async {
    await pumpMain(tester, name: 'Kitchen words');
    await openDialog(tester);
    await tester.enterText(nameField(), 'Garden');
    await tester.pump();
    // a tap on the barrier after a change asks first
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Collection details'), findsNothing);
    expect((tester.widget(title()) as Text).data, 'Kitchen words');
    await tester.runAsync(() async {
      expect((await store.byId(current.collectionId))!.name, 'Kitchen words');
    });
    await tearDownMain(tester);
  });
}

Matcher findsOneComponent() => findsOneWidget;
