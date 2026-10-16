import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/collections/collection_icon.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_view.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('CollectionIcon', () {
    testWidgets('collection shows name, word count and current badge', (t) async {
      var taps = 0, menus = 0;
      await t.pumpWidget(_wrap(SizedBox(
        width: 110,
        child: CollectionIcon(
          kind: CollectionIconKind.collection,
          name: 'Phrasal verbs',
          wordCount: 32,
          isCurrent: true,
          onTap: () => taps++,
          onMenu: () => menus++,
        ),
      )));
      expect(find.text('Phrasal verbs'), findsOneWidget);
      expect(find.text('32 words'), findsOneWidget);
      expect(find.text('current'), findsOneWidget);
      await t.tap(find.text('Phrasal verbs'));
      await t.tap(find.byIcon(Icons.more_vert));
      expect(taps, 1);
      expect(menus, 1);
    });

    testWidgets('folder shows name, no word count, no badge, has ⋮', (t) async {
      await t.pumpWidget(_wrap(CollectionIcon(
        kind: CollectionIconKind.folder,
        name: 'Films',
        onTap: () {},
        onMenu: () {},
      )));
      expect(find.text('Films'), findsOneWidget);
      expect(find.textContaining('words'), findsNothing);
      expect(find.text('current'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('recycle bin has no ⋮', (t) async {
      await t.pumpWidget(_wrap(CollectionIcon(
        kind: CollectionIconKind.recycleBin,
        name: 'Recycle bin',
        onTap: () {},
        onMenu: () {},
      )));
      expect(find.text('Recycle bin'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('long name: two lines with ellipsis', (t) async {
      await t.pumpWidget(_wrap(CollectionIcon(
        kind: CollectionIconKind.collection,
        name: 'A very long collection name ' * 5,
        onTap: () {},
      )));
      final text = t.widget<Text>(find.textContaining('A very long'));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('CollectionsPathBar', () {
    testWidgets('top level: path "Collections", Up disabled', (t) async {
      var ups = 0;
      await t.pumpWidget(_wrap(CollectionsPathBar(
        parts: const [PathPart(null, 'Collections')],
        upEnabled: false,
        onUp: () => ups++,
        onPart: (_) {},
      )));
      expect(find.text('Collections'), findsOneWidget);
      expect(find.text('Up'), findsOneWidget);
      await t.tap(find.text('Up'));
      expect(ups, 0);
    });

    testWidgets('inside a folder: every part tappable, Up enabled', (t) async {
      final tapped = <String?>[];
      var ups = 0;
      await t.pumpWidget(_wrap(CollectionsPathBar(
        parts: const [
          PathPart(null, 'Collections'),
          PathPart('f1', 'English course'),
          PathPart('f2', 'Unit 3'),
        ],
        upEnabled: true,
        onUp: () => ups++,
        onPart: tapped.add,
      )));
      expect(find.text('›'), findsNWidgets(2));
      await t.tap(find.text('Collections'));
      await t.tap(find.text('English course'));
      await t.tap(find.text('Unit 3'));
      expect(tapped, [null, 'f1', 'f2']);
      await t.tap(find.text('Up'));
      expect(ups, 1);
    });
  });

  group('CollectionsGrid', () {
    const items = [
      CollectionItemView(id: 'a', isFolder: true, name: 'English course'),
      CollectionItemView(id: 'b', isFolder: true, name: 'Films'),
      CollectionItemView(
          id: 'c', isFolder: false, name: 'Phrasal verbs', wordCount: 32, isCurrent: true),
      CollectionItemView(id: 'd', isFolder: false, name: '16.10.2026 14:30', wordCount: 0),
    ];

    testWidgets('keeps order and appends the bin last when told', (t) async {
      final tapped = <String>[];
      var binTaps = 0;
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: items,
        showBin: true,
        onTap: (i) => tapped.add(i.id),
        onMenu: (_) {},
        onBinTap: () => binTaps++,
      )));
      final icons = t.widgetList<CollectionIcon>(find.byType(CollectionIcon)).toList();
      expect(icons.map((i) => i.name),
          ['English course', 'Films', 'Phrasal verbs', '16.10.2026 14:30', 'Recycle bin']);
      expect(icons.last.kind, CollectionIconKind.recycleBin);
      expect(find.text('0 words'), findsOneWidget);
      expect(find.text('current'), findsOneWidget);
      await t.tap(find.text('Films'));
      await t.tap(find.text('Recycle bin'));
      expect(tapped, ['b']);
      expect(binTaps, 1);
    });

    testWidgets('menu callback gets the item', (t) async {
      final menued = <String>[];
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: items,
        onTap: (_) {},
        onMenu: (i) => menued.add(i.id),
      )));
      await t.tap(find.byIcon(Icons.more_vert).at(2));
      expect(menued, ['c']);
    });

    testWidgets('no bin inside a folder', (t) async {
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: items,
        onTap: (_) {},
        onMenu: (_) {},
      )));
      expect(find.text('Recycle bin'), findsNothing);
    });

    testWidgets('itemBuilder wraps each item icon (drag slot)', (t) async {
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: items,
        onTap: (_) {},
        onMenu: (_) {},
        itemWrapper: (context, item, icon) =>
            KeyedSubtree(key: ValueKey('wrap-${item.id}'), child: icon),
      )));
      for (final i in items) {
        expect(find.byKey(ValueKey('wrap-${i.id}')), findsOneWidget);
      }
    });

    testWidgets('empty folder shows the hint', (t) async {
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: const [],
        onTap: (_) {},
        onMenu: (_) {},
      )));
      expect(find.text('This folder is empty'), findsOneWidget);
      expect(find.byType(CollectionIcon), findsNothing);
    });

    testWidgets('loading shows a spinner and no icons', (t) async {
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: null,
        showBin: true,
        onTap: (_) {},
        onMenu: (_) {},
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CollectionIcon), findsNothing);
      expect(find.text('This folder is empty'), findsNothing);
    });

    testWidgets('300 collections and 50 folders build', (t) async {
      final many = [
        for (var i = 0; i < 50; i++) CollectionItemView(id: 'f$i', isFolder: true, name: 'F$i'),
        for (var i = 0; i < 300; i++)
          CollectionItemView(id: 'c$i', isFolder: false, name: 'C$i', wordCount: i),
      ];
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: many,
        showBin: true,
        onTap: (_) {},
        onMenu: (_) {},
      )));
      expect(find.text('F0'), findsOneWidget);
    });
  });
}
