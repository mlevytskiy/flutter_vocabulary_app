import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/recycle_bin_screen.dart';

/// collections-screen T19: SCR-08 bin screen, SCR-09 menu, SCR-10 confirmations.
class FakeStore implements CollectionStore {
  FakeStore(List<LevelItem> items, {this.shared = const {}, this.folderName}) {
    _items = [...items];
  }

  late List<LevelItem> _items;
  final Set<String> shared;
  final String? folderName;
  final _ctrl = StreamController<List<LevelItem>>.broadcast();
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  void _push() => _ctrl.add([..._items]);

  @override
  Stream<List<LevelItem>> watchBin() async* {
    yield [..._items];
    yield* _ctrl.stream;
  }

  @override
  Future<({BinResult result, String? folderId, String? folderName})> restore(
      String id) async {
    calls.add('restore $id');
    _items.removeWhere((i) => i.id == id);
    _push();
    return (result: BinResult.done, folderId: null, folderName: folderName);
  }

  @override
  Future<BinResult> erase(String id) async {
    calls.add('erase $id');
    _items.removeWhere((i) => i.id == id);
    _push();
    return BinResult.done;
  }

  @override
  Future<BinResult> emptyBin() async {
    calls.add('empty');
    _items.clear();
    _push();
    return BinResult.done;
  }

  @override
  Future<bool> hasSharedLink(String id) async => shared.contains(id);
}

LevelItem coll(String id, String name, int words, DateTime binnedAt) =>
    LevelItem.collection(WordCollection()
      ..collectionId = id
      ..name = name
      ..words = [for (var i = 0; i < words; i++) WordPair()..word = 'w$i'..translation = 't$i']
      ..binnedAt = binnedAt);

LevelItem fold(String id, String name, DateTime binnedAt) =>
    LevelItem.folder(CollectionFolder()
      ..folderId = id
      ..name = name
      ..binnedAt = binnedAt);

Future<void> pump(WidgetTester tester, FakeStore store,
    {Future<CollectionStore>? future}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      collectionStoreProvider.overrideWith((ref) => future ?? Future.value(store)),
    ],
    child: const MaterialApp(home: RecycleBinScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> openMenu(WidgetTester tester, String row, String action) async {
  await tester.tap(find.text(row));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();
  FakeStore three() => FakeStore([
        coll('c2', 'Lesson 2', 12, now.subtract(const Duration(hours: 1))),
        fold('f1', 'Old films', now.subtract(const Duration(days: 23, hours: 1))),
        coll('c3', '15.09.2026 10:02', 1, now.subtract(const Duration(days: 29, hours: 1))),
      ]);

  testWidgets('default: title, rows with words and days left, newest first', (t) async {
    await pump(t, three());
    expect(find.text('Recycle bin'), findsOneWidget);
    expect(find.text('Lesson 2'), findsOneWidget);
    expect(find.text('12 words'), findsOneWidget);
    expect(find.text('30 days left'), findsOneWidget);
    expect(find.text('7 days left'), findsOneWidget);
    expect(find.text('1 day left'), findsOneWidget);
    expect(find.text('1 word'), findsOneWidget);
    expect(t.getTopLeft(find.text('Lesson 2')).dy,
        lessThan(t.getTopLeft(find.text('Old films')).dy));
    expect(t.widget<TextButton>(find.widgetWithText(TextButton, 'Empty recycle bin')).onPressed,
        isNotNull);
  });

  testWidgets('empty: text and Empty unavailable', (t) async {
    await pump(t, FakeStore([]));
    expect(find.text('The recycle bin is empty'), findsOneWidget);
    expect(t.widget<TextButton>(find.widgetWithText(TextButton, 'Empty recycle bin')).onPressed,
        isNull);
  });

  testWidgets('loading: spinner before the store opens', (t) async {
    final c = Completer<CollectionStore>();
    await pump(t, FakeStore([]), future: c.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a collection row never opens; the menu shows Restore and Delete forever', (t) async {
    await pump(t, three());
    await t.tap(find.text('Lesson 2'));
    await t.pumpAndSettle();
    expect(find.byType(RecycleBinScreen), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete forever'), findsOneWidget);
  });

  testWidgets('restored: row leaves, snackbar names Collections or the folder', (t) async {
    final s = three();
    await pump(t, s);
    await openMenu(t, 'Lesson 2', 'Restore');
    expect(s.calls, ['restore c2']);
    expect(find.text('Lesson 2'), findsNothing);
    expect(find.text('Restored to Collections'), findsOneWidget);
  });

  testWidgets('restored into a folder says its name', (t) async {
    final s = FakeStore([coll('c2', 'Lesson 2', 3, now)], folderName: 'Class');
    await pump(t, s);
    await openMenu(t, 'Lesson 2', 'Restore');
    expect(find.text('Restored to Class'), findsOneWidget);
  });

  testWidgets('erase one: confirm, then gone', (t) async {
    final s = three();
    await pump(t, s);
    await openMenu(t, 'Lesson 2', 'Delete forever');
    expect(find.text('Delete "Lesson 2" forever?'), findsOneWidget);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);
    expect(find.textContaining('shared page'), findsNothing);
    await t.tap(find.widgetWithText(TextButton, 'Delete forever'));
    await t.pumpAndSettle();
    expect(s.calls, ['erase c2']);
    expect(find.text('Lesson 2'), findsNothing);
  });

  testWidgets('erase one with a shared link adds the sentence; Cancel changes nothing', (t) async {
    final s = FakeStore([coll('c2', 'Lesson 2', 3, now)], shared: {'c2'});
    await pump(t, s);
    await openMenu(t, 'Lesson 2', 'Delete forever');
    expect(find.textContaining('shared page'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(s.calls, isEmpty);
    expect(find.text('Lesson 2'), findsOneWidget);
  });

  testWidgets('empty the bin: confirm with count and shared sentence, then all gone', (t) async {
    final s = FakeStore([
      coll('c2', 'Lesson 2', 3, now),
      fold('f1', 'Old films', now),
    ], shared: {'f1'});
    await pump(t, s);
    await t.tap(find.text('Empty recycle bin'));
    await t.pumpAndSettle();
    expect(find.text('Empty the recycle bin?'), findsOneWidget);
    expect(find.textContaining('2 items are erased for good.'), findsOneWidget);
    expect(find.textContaining('shared page'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Empty'));
    await t.pumpAndSettle();
    expect(s.calls, ['empty']);
    expect(find.text('The recycle bin is empty'), findsOneWidget);
  });

  testWidgets('empty the bin cancelled changes nothing', (t) async {
    final s = three();
    await pump(t, s);
    await t.tap(find.text('Empty recycle bin'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(s.calls, isEmpty);
    expect(find.text('Lesson 2'), findsOneWidget);
  });
}
