import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  final opened = <String>[];
  final made = <String?>[];

  @override
  Future<WordCollection> build() async => collection;

  @override
  Future<bool> open(String id) async {
    opened.add(id);
    return true;
  }

  @override
  Future<void> newCollection(String? folderId) async => made.add(folderId);
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
  late _FakeInput input;

  Future<void> pump(WidgetTester t) async {
    store = _FakeStore();
    input = _FakeInput(phrasal);
    await t.pumpWidget(ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        wordInputNotifierProvider.overrideWith(() => input),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([english])),
        collectionLevelProvider('f1').overrideWith((ref) => Stream.value([])),
        collectionLevelProvider(null).overrideWith((ref) => Stream.value([
              LevelItem.folder(english),
              LevelItem.collection(phrasal),
              LevelItem.collection(other),
            ])),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/c', routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('MAIN SCREEN')),
          GoRoute(path: '/c', builder: (_, __) => const CollectionsScreen()),
        ]),
      ),
    ));
    await t.pump();
    await t.pump();
  }

  /// Opens the plus button and taps one of its actions.
  Future<void> plus(WidgetTester t, String action) async {
    await t.tap(find.byIcon(Icons.add));
    await t.pumpAndSettle();
    await t.tap(find.text(action));
    await t.pumpAndSettle();
  }

  testWidgets('New folder asks for a name and creates it in the open folder',
      (t) async {
    await pump(t);
    await plus(t, 'New folder');
    expect(find.text('New folder'), findsWidgets);
    await t.enterText(find.byType(TextField), 'Unit 9');
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();
    expect(store.created, [(parentId: null, name: 'Unit 9')]);
  });

  testWidgets('Cancel in the New folder dialog creates nothing', (t) async {
    await pump(t);
    await plus(t, 'New folder');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(store.created, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('no item menu: no ⋮, and a long press opens nothing',
      (t) async {
    await pump(t);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    await t.longPress(find.text('Films words'));
    await t.pumpAndSettle();
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('a tap on a collection opens it and goes to the main screen',
      (t) async {
    await pump(t);
    await t.tap(find.text('Films words'));
    await t.pumpAndSettle();
    expect(input.opened, [other.collectionId]);
    expect(find.text('MAIN SCREEN'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a tap on the current collection still goes to the main screen',
      (t) async {
    await pump(t);
    await t.tap(find.text('Phrasal verbs'));
    await t.pumpAndSettle();
    expect(find.text('MAIN SCREEN'), findsOneWidget);
  });

  testWidgets('New collection makes one at the top level and opens main',
      (t) async {
    await pump(t);
    await plus(t, 'New collection');
    expect(input.made, [null]);
    expect(find.text('MAIN SCREEN'), findsOneWidget);
  });

  testWidgets('New collection inside a folder makes it in that folder',
      (t) async {
    await pump(t);
    await t.tap(find.text('English course'));
    await t.pumpAndSettle();
    await plus(t, 'New collection');
    expect(input.made, ['f1']);
    expect(find.text('MAIN SCREEN'), findsOneWidget);
  });
}
