import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/features/collections/collection_icon.dart';
import 'package:flutter_vocabulary_app/features/collections/collection_pictures.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_notifier.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_view.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('CollectionIcon', () {
    testWidgets('collection shows name, word count and current badge',
        (t) async {
      var taps = 0;
      await t.pumpWidget(_wrap(SizedBox(
        width: 110,
        child: CollectionIcon(
          kind: CollectionIconKind.collection,
          name: 'Phrasal verbs',
          wordCount: 32,
          isCurrent: true,
          onTap: () => taps++,
        ),
      )));
      expect(find.text('Phrasal verbs'), findsOneWidget);
      expect(find.text('32 words'), findsOneWidget);
      expect(find.text('current'), findsOneWidget);
      expect(find.byType(DocumentPicture), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      await t.tap(find.text('Phrasal verbs'));
      expect(taps, 1);
    });

    testWidgets('folder shows the folder picture, name, no word count, no ⋮',
        (t) async {
      await t.pumpWidget(_wrap(CollectionIcon(
        kind: CollectionIconKind.folder,
        name: 'Films',
        onTap: () {},
      )));
      expect(find.text('Films'), findsOneWidget);
      expect(find.byType(FolderPicture), findsOneWidget);
      expect(find.textContaining('words'), findsNothing);
      expect(find.text('current'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('a collection shows one corner badge per kind of source',
        (t) async {
      await t.pumpWidget(_wrap(const CollectionIcon(
        kind: CollectionIconKind.collection,
        name: 'Mixed',
        badges: [SourceBadge.quizlet, SourceBadge.movie, SourceBadge.image],
      )));
      final badges = t
          .widgetList<SourceBadgePicture>(find.byType(SourceBadgePicture))
          .map((b) => b.badge);
      expect(
          badges, [SourceBadge.quizlet, SourceBadge.movie, SourceBadge.image]);
      expect(find.text('Q'), findsOneWidget);
      // as many sources as you like, the outline stays plain
      expect(t.widget<DocumentPicture>(find.byType(DocumentPicture)).look,
          DocumentLook.plain);
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

  group('CollectionsUpButton', () {
    testWidgets('an arrow with the tooltip Up; disabled does nothing',
        (t) async {
      var ups = 0;
      await t.pumpWidget(
          _wrap(CollectionsUpButton(enabled: false, onUp: () => ups++)));
      await t.tap(find.byTooltip('Up'));
      expect(ups, 0);
      await t.pumpWidget(
          _wrap(CollectionsUpButton(enabled: true, onUp: () => ups++)));
      await t.tap(find.byTooltip('Up'));
      expect(ups, 1);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });
  });

  group('CollectionsPathBar', () {
    testWidgets('every part tappable, on one line', (t) async {
      final tapped = <String?>[];
      await t.pumpWidget(_wrap(CollectionsPathBar(
        parts: const [
          PathPart(null, 'Collections'),
          PathPart('f1', 'English course'),
          PathPart('f2', 'Unit 3'),
        ],
        onPart: tapped.add,
      )));
      expect(find.text('›'), findsNWidgets(2));
      await t.tap(find.text('Collections'));
      await t.tap(find.text('English course'));
      await t.tap(find.text('Unit 3'));
      expect(tapped, [null, 'f1', 'f2']);
      final ys = {
        for (final s in ['Collections', 'English course', 'Unit 3'])
          t.getCenter(find.text(s)).dy.round(),
      };
      expect(ys, hasLength(1));
    });

    testWidgets('a long path stays one line and shows the open folder',
        (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: CollectionsUpButton(enabled: true, onUp: () {}),
            titleSpacing: 0,
            title: CollectionsPathBar(
              parts: [
                const PathPart(null, 'Collections'),
                for (var i = 1; i <= 6; i++)
                  PathPart('f$i', 'A rather long folder $i'),
              ],
              onPart: (_) {},
            ),
          ),
        ),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      final open = t.getRect(find.text('A rather long folder 6'));
      final bar = t.getRect(find.byType(AppBar));
      expect(open.right, lessThanOrEqualTo(bar.right));
      expect(open.left, greaterThanOrEqualTo(0));
      expect(t.getCenter(find.text('A rather long folder 5')).dy,
          moreOrLessEquals(open.center.dy, epsilon: 2));
    });
  });

  group('CollectionsGrid', () {
    const items = [
      CollectionItemView(id: 'a', isFolder: true, name: 'English course'),
      CollectionItemView(id: 'b', isFolder: true, name: 'Films'),
      CollectionItemView(
          id: 'c',
          isFolder: false,
          name: 'Phrasal verbs',
          wordCount: 32,
          isCurrent: true),
      CollectionItemView(
          id: 'd', isFolder: false, name: '16.10.2026 14:30', wordCount: 0),
    ];

    testWidgets('keeps order; no recycle bin tile', (t) async {
      final tapped = <String>[];
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: items,
        onTap: (i) => tapped.add(i.id),
      )));
      final icons =
          t.widgetList<CollectionIcon>(find.byType(CollectionIcon)).toList();
      expect(icons.map((i) => i.name),
          ['English course', 'Films', 'Phrasal verbs', '16.10.2026 14:30']);
      expect(find.text('Recycle bin'), findsNothing);
      expect(find.text('0 words'), findsOneWidget);
      expect(find.text('current'), findsOneWidget);
      await t.tap(find.text('Films'));
      expect(tapped, ['b']);
    });

    testWidgets('itemBuilder wraps each item icon (drag slot)', (t) async {
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: items,
        onTap: (_) {},
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
      )));
      expect(find.text('This folder is empty'), findsOneWidget);
      expect(find.byType(CollectionIcon), findsNothing);
    });

    testWidgets('loading shows a spinner and no icons', (t) async {
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: null,
        onTap: (_) {},
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CollectionIcon), findsNothing);
      expect(find.text('This folder is empty'), findsNothing);
    });

    testWidgets('300 collections and 50 folders build', (t) async {
      final many = [
        for (var i = 0; i < 50; i++)
          CollectionItemView(id: 'f$i', isFolder: true, name: 'F$i'),
        for (var i = 0; i < 300; i++)
          CollectionItemView(
              id: 'c$i', isFolder: false, name: 'C$i', wordCount: i),
      ];
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: many,
        onTap: (_) {},
      )));
      expect(find.text('F0'), findsOneWidget);
    });
    testWidgets('pictures line up whatever the name and badges', (t) async {
      await t.pumpWidget(_wrap(CollectionsGrid(
        items: const [
          CollectionItemView(id: 'a', isFolder: false, name: 'A'),
          CollectionItemView(
              id: 'b',
              isFolder: false,
              name: 'A rather long collection name',
              badges: [SourceBadge.quizlet, SourceBadge.movie]),
        ],
        onTap: (_) {},
        // As the screen's locked wrapper: loose constraints.
        itemWrapper: (context, item, icon) =>
            Align(alignment: AlignmentDirectional.topStart, child: icon),
      )));
      final tiles = find.byType(CollectionIcon);
      expect(t.getSize(tiles.at(0)).width, t.getSize(tiles.at(1)).width);
      for (var i = 0; i < 2; i++) {
        final picture = find.descendant(
            of: tiles.at(i), matching: find.byType(CollectionPicture));
        expect(t.getCenter(picture).dx, t.getCenter(tiles.at(i)).dx);
      }
    });
  });

  group('badgesOf', () {
    SessionSource src(SourceKind k) => SessionSource()..kind = k;

    test('none for no sources', () => expect(badgesOf(const []), isEmpty));

    test('one per kind, Quizlet, film, photo; duplicates once', () {
      expect(
          badgesOf([
            src(SourceKind.photo),
            src(SourceKind.subtitles),
            src(SourceKind.photo),
            src(SourceKind.set),
          ]),
          [SourceBadge.quizlet, SourceBadge.movie, SourceBadge.image]);
      expect(badgesOf([src(SourceKind.photo), src(SourceKind.subtitles)]),
          [SourceBadge.movie, SourceBadge.image]);
    });
  });
}
