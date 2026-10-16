import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/notes/notes_screen.dart';
import 'package:flutter_vocabulary_app/features/tags/typed_tag_field.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

import 'photo_preview_test.dart' show MapSourcePhotoStore, kPng;

/// collection-tags T12 (SCR-08, AC-15, 16, 29, 34): the Notes page's tag
/// fields are typed, suggest only while focused and say when the collection
/// refused a source's tag.

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection, {this.refuse = const {}});
  final WordCollection collection;
  final Set<TagKind> refuse;
  final calls = <({List<String>? origin, List<String>? topic})>[];
  final collectionCalls = <(TagKind, List<String>)>[];

  @override
  Future<WordCollection> build() async => collection;

  @override
  Future<Set<TagKind>> updateSourceNote(
    String id, {
    String? title,
    String? description,
    List<String>? links,
    List<String>? origin,
    List<String>? topic,
  }) async {
    calls.add((origin: origin, topic: topic));
    final s = collection.sources.firstWhere((s) => s.id == id);
    if (origin != null) s.originTags = [...origin];
    if (topic != null) s.topicTags = [...topic];
    state = AsyncData(collection);
    return {
      if (origin != null && refuse.contains(TagKind.origin)) TagKind.origin,
      if (topic != null && refuse.contains(TagKind.topic)) TagKind.topic,
    };
  }

  @override
  Future<bool> setCollectionTags(TagKind kind, List<String> tags) async {
    collectionCalls.add((kind, tags));
    return true;
  }
}

WordCollection _collection({List<String> legacy = const []}) =>
    WordCollection.create()
      ..tags = legacy
      ..sources = [
        SessionSource()
          ..id = 'p1'
          ..fileName = 'p1.jpg'
          ..takenAt = DateTime(2026, 10, 15, 9),
      ]
      ..words = [
        WordPair(
            word: 'cup', translation: 'чашка', sourceId: 'p1', rowId: 'r1'),
        WordPair(word: '', translation: ''),
      ];

void main() {
  late _FakeInput input;

  Future<void> pump(WidgetTester tester, _FakeInput fake) async {
    input = fake;
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => fake),
      collectionStoreProvider
          .overrideWith((ref) => Completer<CollectionStore>().future),
      nonEmptyCollectionsProvider
          .overrideWith((ref) => Stream.value(const <WordCollection>[])),
      sourcePhotoStoreProvider
          .overrideWithValue(MapSourcePhotoStore({'p1': kPng})),
    ]);
    addTearDown(container.dispose);
    await tester
        .runAsync(() => container.read(wordInputNotifierProvider.future));
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => const NotesScreen(selectedId: 'p1')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Finder pager() => find.byKey(NotesScreen.pagerKey('p1'));

  Future<Finder> toSourceField(WidgetTester tester, Key key) async {
    await tester.drag(pager(), const Offset(400, 0));
    await tester.pumpAndSettle();
    final f = find.descendant(of: pager(), matching: find.byKey(key));
    await tester.scrollUntilVisible(f, 60,
        scrollable: find
            .descendant(of: pager(), matching: find.byType(Scrollable))
            .at(1));
    await tester.pumpAndSettle();
    return f;
  }

  Future<void> add(WidgetTester tester, Finder field, String text) async {
    await tester.enterText(field, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  testWidgets(
      'two fields sit at the top and a collection tag goes to the notifier',
      (tester) async {
    await pump(tester, _FakeInput(_collection()));
    expect(find.byKey(NotesScreen.collectionOriginTagFieldKey), findsOneWidget);
    expect(find.byKey(NotesScreen.collectionTagFieldKey), findsOneWidget);
    expect(find.byType(TypedTagField), findsNWidgets(2));
    await add(tester, find.byKey(NotesScreen.collectionTagFieldKey), 'Food');
    await add(
        tester, find.byKey(NotesScreen.collectionOriginTagFieldKey), 'Friends');
    expect([for (final c in input.collectionCalls) '${c.$1.name}:${c.$2}'],
        ['topic:[Food]', 'origin:[Friends]']);
    await finish(tester);
  });

  testWidgets(
      'each source note has two fields and suggestions show only when focused',
      (tester) async {
    await pump(tester, _FakeInput(_collection()));
    final topic = await toSourceField(tester, NotesScreen.tagFieldKey);
    expect(find.descendant(of: pager(), matching: find.byType(TypedTagField)),
        findsNWidgets(2));
    expect(
        find.descendant(
            of: pager(), matching: find.byKey(NotesScreen.originTagFieldKey)),
        findsOneWidget);
    // Not focused: no helper line, no suggestion chips.
    expect(find.text(TypedTagField.helperFor(TagKind.topic)), findsNothing);
    await tester.tap(topic);
    await tester.pumpAndSettle();
    expect(find.text(TypedTagField.helperFor(TagKind.topic)), findsOneWidget);
    await finish(tester);
  });

  testWidgets('adding a source topic tag calls updateSourceNote with topic',
      (tester) async {
    await pump(tester, _FakeInput(_collection()));
    final topic = await toSourceField(tester, NotesScreen.tagFieldKey);
    await add(tester, topic, 'Kitchen');
    expect(input.calls.single.topic, ['Kitchen']);
    expect(input.calls.single.origin, isNull);
    expect(find.byType(SnackBar), findsNothing);
    await finish(tester);
  });

  testWidgets('a refused topic kind shows the snackbar once', (tester) async {
    await pump(tester, _FakeInput(_collection(), refuse: {TagKind.topic}));
    final topic = await toSourceField(tester, NotesScreen.tagFieldKey);
    await add(tester, topic, 'Kitchen');
    expect(
        find.text('The collection already has 10 topic tags — not added to it'),
        findsOneWidget);
    await finish(tester);
  });

  testWidgets('legacy tags show as topic tags before the migration',
      (tester) async {
    final c = _collection(legacy: ['B1 course']);
    c.sources.first.tags = ['food'];
    await pump(tester, _FakeInput(c));
    expect(find.widgetWithText(InputChip, 'B1 course'), findsOneWidget);
    await toSourceField(tester, NotesScreen.tagFieldKey);
    expect(
        find.descendant(
            of: pager(), matching: find.widgetWithText(InputChip, 'food')),
        findsOneWidget);
    await finish(tester);
  });
}
