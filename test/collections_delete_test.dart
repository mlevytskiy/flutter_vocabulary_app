@Tags(['smoke'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/bin_dialogs.dart';
import 'package:flutter_vocabulary_app/features/collections/bin_drop_zone.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;
  @override
  Future<WordCollection> build() async => collection;
}

class _FakeStore implements CollectionStore {
  final previews = <String, BinPreview>{};
  final binned = <String>[];
  final previewed = <String>[];
  String? stayedName;

  @override
  Future<BinPreview?> binPreview(String id) async {
    previewed.add(id);
    return previews[id];
  }

  @override
  Future<({BinResult result, String? stayedName})> bin(String id,
      {DateTime? now}) async {
    binned.add(id);
    return (result: BinResult.done, stayedName: stayedName);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

void main() {
  final english = _folder('f1', 'English course', null);
  final phrasal = _coll('Phrasal verbs', 3);
  final films = _coll('Films words', 1);
  final lesson = _coll('Lesson 3', 24);
  late _FakeStore store;

  Future<void> pump(WidgetTester t) async {
    store = _FakeStore()
      ..previews[films.collectionId] = (
        name: 'Films words',
        isFolder: false,
        wordCount: 1,
        collections: 0,
        folders: 0,
        currentStaysName: null
      )
      ..previews[lesson.collectionId] = (
        name: 'Lesson 3',
        isFolder: false,
        wordCount: 24,
        collections: 0,
        folders: 0,
        currentStaysName: null
      )
      ..previews['f1'] = (
        name: 'English course',
        isFolder: true,
        wordCount: 0,
        collections: 3,
        folders: 1,
        currentStaysName: null
      );
    await t.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        wordInputNotifierProvider.overrideWith(() => _FakeInput(phrasal)),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([english])),
        collectionLevelProvider(null).overrideWith((ref) => Stream.value([
              LevelItem.folder(english),
              LevelItem.collection(phrasal),
              LevelItem.collection(films),
            ])),
        collectionLevelProvider('f1').overrideWith(
            (ref) => Stream.value([LevelItem.collection(lesson)])),
      ],
      child: const MaterialApp(home: CollectionsScreen()),
    ));
    await t.pump();
    await t.pump();
  }

  Future<void> menuDelete(WidgetTester t, String name) async {
    final icon = find.descendant(
      of: find
          .ancestor(of: find.text(name), matching: find.byType(InkWell))
          .first,
      matching: find.byIcon(Icons.more_vert),
    );
    await t.tap(icon.first);
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
  }

  Future<void> drag(WidgetTester t, Finder from, Offset to) async {
    final g = await t.startGesture(t.getCenter(from));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 30));
    await t.pump();
    await g.moveTo(to);
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
  }

  testWidgets('SCR-07 collection: confirmation with the word count, then bin',
      (t) async {
    await pump(t);
    await menuDelete(t, 'Films words');
    expect(find.text('Delete "Films words"?'), findsOneWidget);
    expect(find.textContaining('1 word. It goes to the recycle bin'),
        findsOneWidget);
    expect(store.binned, isEmpty);
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(store.binned, [films.collectionId]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('SCR-07 cancel changes nothing', (t) async {
    await pump(t);
    await menuDelete(t, 'Films words');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(store.binned, isEmpty);
  });

  testWidgets('SCR-07 folder: counts, then bin', (t) async {
    await pump(t);
    await menuDelete(t, 'English course');
    expect(
        find.textContaining('3 collections and 1 folder go to the recycle bin'),
        findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(store.binned, ['f1']);
  });

  testWidgets(
      'SCR-07 folder with current: says it stays; SCR-04 current stayed',
      (t) async {
    await pump(t);
    store
      ..previews['f1'] = (
        name: 'English course',
        isFolder: true,
        wordCount: 0,
        collections: 2,
        folders: 0,
        currentStaysName: 'Lesson 4'
      )
      ..stayedName = 'Lesson 4';
    await menuDelete(t, 'English course');
    expect(
        find.textContaining(
            '"Lesson 4" stays, because it is the current collection'),
        findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(store.binned, ['f1']);
    expect(find.text(stayedText('Lesson 4')), findsOneWidget);
  });

  testWidgets('SCR-04 refused current: Delete from the menu', (t) async {
    await pump(t);
    await menuDelete(t, 'Phrasal verbs');
    expect(find.text(refusedCurrentText), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.previewed, isEmpty);
    expect(store.binned, isEmpty);
  });

  testWidgets('a drop on the bin icon (top level) asks, then bins', (t) async {
    await pump(t);
    expect(find.byType(BinDropZone), findsNothing);
    await drag(
        t, find.text('Films words'), t.getCenter(find.text('Recycle bin')));
    expect(find.text('Delete "Films words"?'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(store.binned, [films.collectionId]);
  });

  testWidgets('the current collection dropped on the bin icon is refused',
      (t) async {
    await pump(t);
    await drag(
        t, find.text('Phrasal verbs'), t.getCenter(find.text('Recycle bin')));
    expect(find.text(refusedCurrentText), findsOneWidget);
    expect(store.binned, isEmpty);
    expect(store.previewed, isEmpty);
  });

  testWidgets(
      'inside a folder the BinDropZone shows only while dragging and takes the drop',
      (t) async {
    await pump(t);
    await t.tap(find.text('English course'));
    await t.pumpAndSettle();
    expect(find.byType(BinDropZone), findsNothing);
    final g = await t.startGesture(t.getCenter(find.text('Lesson 3')));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 30));
    await t.pump();
    expect(find.byType(BinDropZone), findsOneWidget);
    await g.moveTo(t.getCenter(find.byType(BinDropZone)));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(find.text('Delete "Lesson 3"?'), findsOneWidget);
    expect(find.byType(BinDropZone), findsNothing);
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(store.binned, [lesson.collectionId]);
  });
}
