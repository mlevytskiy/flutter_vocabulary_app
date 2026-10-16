import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

CollectionFolder _folder(String id, String name, String? parent) =>
    CollectionFolder()
      ..folderId = id
      ..name = name
      ..parentId = parent;

WordCollection _coll(String name, int words) => WordCollection.create()
  ..name = name
  ..words = [
    for (var i = 0; i < words; i++) WordPair(word: 'w$i', translation: 't$i')
  ];

final upButton =
    find.ancestor(of: find.text('Up'), matching: find.bySubtype<TextButton>());

void main() {
  final english = _folder('f1', 'English course', null);
  final unit3 = _folder('f2', 'Unit 3', 'f1');
  final empty = _folder('f3', 'Unit 4', 'f1');
  final phrasal = _coll('Phrasal verbs', 32);
  final lesson = _coll('Lesson 3', 24);

  Future<void> pump(WidgetTester t, {bool loading = false}) async {
    final levels = <String?, List<LevelItem>>{
      null: [LevelItem.folder(english), LevelItem.collection(phrasal)],
      'f1': [LevelItem.folder(unit3), LevelItem.folder(empty)],
      'f2': [LevelItem.collection(lesson)],
      'f3': [],
    };
    await t.pumpWidget(ProviderScope(
      overrides: [
        wordInputNotifierProvider.overrideWith(() => _FakeInput(phrasal)),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([english, unit3, empty])),
        for (final e in levels.entries)
          collectionLevelProvider(e.key).overrideWith(
              (ref) => loading ? const Stream.empty() : Stream.value(e.value)),
      ],
      child: const MaterialApp(home: CollectionsScreen()),
    ));
    await t.pump();
    // a short step also runs the plus button's start-up timer
    await t.pump(const Duration(milliseconds: 1));
  }

  testWidgets('top level: no path bar, items in order, current, no ⋮',
      (t) async {
    await pump(t);
    expect(find.widgetWithText(AppBar, 'Collections'), findsOneWidget);
    expect(find.text('Up'), findsNothing);
    expect(find.text('English course'), findsOneWidget);
    expect(find.text('Phrasal verbs'), findsOneWidget);
    expect(find.text('32 words'), findsOneWidget);
    expect(find.text('current'), findsOneWidget);
    expect(t.getTopLeft(find.text('English course')).dx,
        lessThan(t.getTopLeft(find.text('Phrasal verbs')).dx));
    // no bin tile and no menu buttons; the bin is a round button
    expect(find.text('Recycle bin'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('round buttons: Settings, Recycle bin, plus; no top bar actions',
      (t) async {
    await pump(t);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Recycle bin'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.byType(IconButton)),
        findsNothing);
  });

  testWidgets('folder tap grows the path; path part and Up go back', (t) async {
    await pump(t);
    await t.tap(find.text('English course'));
    await t.pump();
    await t.pump();
    expect(find.text('Unit 3'), findsOneWidget);
    expect(find.text('›'), findsOneWidget);
    expect(t.widget<TextButton>(upButton).onPressed, isNotNull);

    await t.tap(find.text('Unit 3'));
    await t.pump();
    await t.pump();
    expect(find.text('›'), findsNWidgets(2));
    expect(find.text('Lesson 3'), findsOneWidget);
    expect(find.text('24 words'), findsOneWidget);

    await t.tap(upButton);
    await t.pump();
    await t.pump();
    expect(find.text('›'), findsOneWidget);
    expect(find.text('Unit 4'), findsOneWidget);

    // the first path part is "Collections" in the path bar (the AppBar title comes later in the tree)
    await t.tap(find.text('Collections').first);
    await t.pump();
    await t.pump();
    expect(find.text('›'), findsNothing);
    expect(find.text('Up'), findsNothing);
  });

  testWidgets('empty folder shows the hint', (t) async {
    await pump(t);
    await t.tap(find.text('English course'));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Unit 4'));
    await t.pump();
    await t.pump();
    expect(find.text('This folder is empty'), findsOneWidget);
    expect(find.text('Up'), findsOneWidget);
  });

  testWidgets('loading at the top level shows a spinner, no path bar',
      (t) async {
    await pump(t, loading: true);
    expect(find.text('Up'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
