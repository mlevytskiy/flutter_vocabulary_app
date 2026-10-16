import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_screen.dart';
import 'package:flutter_vocabulary_app/features/collections/name_dialog.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

class _FakeStore implements CollectionStore {
  final created = <({String? parentId, String name})>[];
  final renamed = <({String id, String name})>[];

  @override
  Future<({FilingResult result, CollectionFolder? folder})> createFolder({
    String? parentId,
    required String name,
  }) async {
    created.add((parentId: parentId, name: name));
    return (result: FilingResult.done, folder: null);
  }

  @override
  Future<FilingResult> rename(String id, String name) async {
    renamed.add((id: id, name: name));
    return FilingResult.done;
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
  final other = _coll('Films words', 1);
  late _FakeStore store;

  Future<void> pump(WidgetTester t) async {
    store = _FakeStore();
    await t.pumpWidget(ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        wordInputNotifierProvider.overrideWith(() => _FakeInput(phrasal)),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([english])),
        collectionLevelProvider(null).overrideWith((ref) => Stream.value([
              LevelItem.folder(english),
              LevelItem.collection(phrasal),
              LevelItem.collection(other),
            ])),
      ],
      child: const MaterialApp(home: CollectionsScreen()),
    ));
    await t.pump();
    await t.pump();
  }

  Future<void> openMenuOf(WidgetTester t, String name) async {
    final icon = find.descendant(
      of: find
          .ancestor(of: find.text(name), matching: find.byType(InkWell))
          .first,
      matching: find.byIcon(Icons.more_vert),
    );
    await t.tap(icon.first);
    await t.pumpAndSettle();
  }

  testWidgets('New folder asks for a name and creates it in the open folder',
      (t) async {
    await pump(t);
    await t.tap(find.byTooltip('New folder'));
    await t.pumpAndSettle();
    expect(find.text('New folder'), findsWidgets);
    await t.enterText(find.byType(TextField), 'Unit 9');
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();
    expect(store.created, [(parentId: null, name: 'Unit 9')]);
  });

  testWidgets('Cancel in the New folder dialog creates nothing', (t) async {
    await pump(t);
    await t.tap(find.byTooltip('New folder'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(store.created, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the menu button opens Rename and Delete; Rename renames',
      (t) async {
    await pump(t);
    await openMenuOf(t, 'Films words');
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await t.tap(find.text('Rename'));
    await t.pumpAndSettle();
    expect(find.text('Rename collection'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Films words'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Movies');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(store.renamed.single.name, 'Movies');
    expect(store.renamed.single.id, other.collectionId);
  });

  testWidgets('a folder renames through the folder dialog', (t) async {
    await pump(t);
    await openMenuOf(t, 'English course');
    await t.tap(find.text('Rename'));
    await t.pumpAndSettle();
    expect(find.text('Rename folder'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Course');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(store.renamed, [(id: 'f1', name: 'Course')]);
  });

  testWidgets('an invalid name keeps the dialog open and renames nothing',
      (t) async {
    await pump(t);
    await openMenuOf(t, 'Films words');
    await t.tap(find.text('Rename'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text(nameProblemMessage), findsOneWidget);
    expect(store.renamed, isEmpty);
  });

  testWidgets('the current collection\'s menu still shows Delete', (t) async {
    await pump(t);
    await openMenuOf(t, 'Phrasal verbs');
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a long press released without moving opens the menu', (t) async {
    await pump(t);
    await t.longPress(find.text('Films words'));
    await t.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
