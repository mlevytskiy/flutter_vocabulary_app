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
import 'package:flutter_vocabulary_app/features/collections/collection_drag.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_screen.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_view.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;
  @override
  Future<WordCollection> build() async => collection;
}

/// Records every call; only move and reorder are expected from a drag.
class _FakeStore implements CollectionStore {
  final calls = <String>[];
  final others = <String>[];

  @override
  Future<FilingResult> move(String id, String? target, {int? at}) async {
    calls.add('move $id -> $target at $at');
    return FilingResult.done;
  }

  @override
  Future<FilingResult> reorder(String id, int index) async {
    calls.add('reorder $id $index');
    return FilingResult.done;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    others.add(invocation.memberName.toString());
    return null;
  }
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
  final unit3 = _folder('f2', 'Unit 3', 'f1');
  final phrasal = _coll('Phrasal verbs', 3);
  final films = _coll('Films words', 1);
  final lesson = _coll('Lesson 3', 2);
  late _FakeStore store;

  Future<void> pump(WidgetTester t) async {
    store = _FakeStore();
    await t.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) async => store),
        wordInputNotifierProvider.overrideWith(() => _FakeInput(phrasal)),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([english, unit3])),
        collectionLevelProvider(null).overrideWith((ref) => Stream.value([
              LevelItem.folder(english),
              LevelItem.collection(phrasal),
              LevelItem.collection(films),
            ])),
        collectionLevelProvider('f1').overrideWith((ref) => Stream.value([
              LevelItem.folder(unit3),
              LevelItem.collection(lesson),
            ])),
        collectionLevelProvider('f2').overrideWith((ref) => Stream.value([])),
      ],
      child: const MaterialApp(home: CollectionsScreen()),
    ));
    await t.pump();
    await t.pump();
  }

  /// A long press that moves to [to], optionally held there, then let go.
  Future<void> drag(WidgetTester t, Finder from, Offset to,
      {Duration hold = Duration.zero}) async {
    final g = await t.startGesture(t.getCenter(from));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 30));
    await t.pump();
    await g.moveTo(to);
    await t.pump();
    if (hold > Duration.zero) await t.pump(hold);
    await g.up();
    await t.pumpAndSettle();
  }

  Offset gapBefore(WidgetTester t, int i) {
    final r = t.getRect(find.byType(DraggableCollectionIcon).at(i));
    return Offset(r.left + 3, r.center.dy);
  }

  testWidgets('a collection dropped on a folder icon moves into it', (t) async {
    await pump(t);
    await drag(
        t, find.text('Films words'), t.getCenter(find.text('English course')));
    expect(store.calls, ['move ${films.collectionId} -> f1 at null']);
  });

  testWidgets('a collection dropped on another collection takes its place',
      (t) async {
    await pump(t);
    await drag(
        t, find.text('Films words'), t.getCenter(find.text('Phrasal verbs')));
    expect(store.calls, ['reorder ${films.collectionId} 1']);
  });

  testWidgets('a drop on a gap reorders', (t) async {
    await pump(t);
    await drag(t, find.text('Films words'), gapBefore(t, 0));
    expect(store.calls, ['reorder ${films.collectionId} 0']);
  });

  testWidgets('Up and a path part are move targets', (t) async {
    await pump(t);
    await t.tap(find.text('English course'));
    await t.pumpAndSettle();
    await drag(t, find.text('Lesson 3'), t.getCenter(find.text('Up')));
    await drag(
        t,
        find.text('Lesson 3'),
        t.getCenter(find.descendant(
            of: find.byType(CollectionsPathBar),
            matching: find.text('Collections'))));
    expect(store.calls, [
      'move ${lesson.collectionId} -> null at null',
      'move ${lesson.collectionId} -> null at null',
    ]);
  });

  testWidgets('a folder onto itself springs back with the message', (t) async {
    await pump(t);
    await drag(t, find.text('English course'),
        t.getCenter(find.text('English course')));
    expect(find.text(RefusedIntoItself.message), findsOneWidget);
    expect(store.calls, isEmpty);
  });

  testWidgets('no-op drops do nothing: empty spot, Up at top, own gap',
      (t) async {
    await pump(t);
    await drag(t, find.text('Films words'), const Offset(400, 500));
    await drag(t, find.text('Films words'), t.getCenter(find.text('Up')));
    expect(store.calls, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Collections'), findsWidgets);
  });

  testWidgets(
      'held about 1 s over a folder it opens mid-drag; the drag goes on',
      (t) async {
    await pump(t);
    await drag(
        t, find.text('Films words'), t.getCenter(find.text('English course')),
        hold: const Duration(milliseconds: 1100));
    // the folder opened (path grew) and the drop went to the opened level's
    // folder icon "English course" no longer there: nothing but the open.
    expect(find.text('Up'), findsOneWidget);
    expect(
        t
            .widget<TextButton>(find.ancestor(
                of: find.text('Up'), matching: find.bySubtype<TextButton>()))
            .onPressed,
        isNotNull);
    expect(find.text('Unit 3'), findsOneWidget);
  });

  testWidgets('after a hover-open, the drag drops into the opened level folder',
      (t) async {
    await pump(t);
    final g = await t.startGesture(t.getCenter(find.text('Films words')));
    await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 30));
    await g.moveTo(t.getCenter(find.text('English course')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1100));
    await t.pump();
    await g.moveTo(t.getCenter(find.text('Unit 3')));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(store.calls, ['move ${films.collectionId} -> f2 at null']);
  });

  testWidgets('QG-6: 50 scripted drags never touch the current pointer',
      (t) async {
    await pump(t);
    final kinds = <Future<void> Function()>[
      () => drag(t, find.text('Films words'),
          t.getCenter(find.text('English course'))),
      () => drag(
          t, find.text('Films words'), t.getCenter(find.text('Phrasal verbs'))),
      () => drag(t, find.text('Films words'), gapBefore(t, 0)),
      () => drag(t, find.text('Phrasal verbs'),
          t.getCenter(find.text('English course'))),
      () => drag(t, find.text('English course'),
          t.getCenter(find.text('English course'))),
      () => drag(t, find.text('Films words'), const Offset(400, 500)),
      () => drag(t, find.text('Films words'), t.getCenter(find.text('Up'))),
    ];
    for (var i = 0; i < 50; i++) {
      await kinds[i % kinds.length]();
    }
    expect(store.others, isEmpty);
    expect(
        store.calls
            .every((c) => c.startsWith('move') || c.startsWith('reorder')),
        isTrue);
    expect(find.text('current'), findsOneWidget);
  });
}
