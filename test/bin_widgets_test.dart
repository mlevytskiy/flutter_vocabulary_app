import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/collections/bin_dialogs.dart';
import 'package:flutter_vocabulary_app/features/collections/bin_drop_zone.dart';
import 'package:flutter_vocabulary_app/features/collections/recycle_bin_view.dart';

/// Pumps a button that runs [ask] and records what it returned.
Future<List<bool>> pumpAsker(
  WidgetTester tester,
  Future<bool> Function(BuildContext context) ask,
) async {
  final answers = <bool>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => answers.add(await ask(context)),
          child: const Text('ask'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ask'));
  await tester.pumpAndSettle();
  return answers;
}

Future<void> pumpList(
  WidgetTester tester,
  List<BinItemView>? items, {
  ValueChanged<BinItemView>? onRestore,
  ValueChanged<BinItemView>? onDeleteForever,
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecycleBinList(
          items: items,
          onRestore: onRestore ?? (_) {},
          onDeleteForever: onDeleteForever ?? (_) {},
        ),
      ),
    ));

const lesson2 = BinItemView(
    id: 'c2', isFolder: false, name: 'Lesson 2', wordCount: 12, daysLeft: 30);
const oldFilms =
    BinItemView(id: 'f1', isFolder: true, name: 'Old films', daysLeft: 7);
const dated = BinItemView(
    id: 'c3', isFolder: false, name: '15.09.2026 10:02', wordCount: 1, daysLeft: 1);

void main() {
  group('SCR-07 confirmBin', () {
    testWidgets('collection: name, word count, Delete returns true', (tester) async {
      final answers = await pumpAsker(
        tester,
        (c) => confirmBin(
            c, const BinPreviewView(name: 'Lesson 3', isFolder: false, wordCount: 24)),
      );
      expect(find.text('Delete "Lesson 3"?'), findsOneWidget);
      expect(
          find.text(
              '24 words. It goes to the recycle bin for 30 days. Its shared link keeps working.'),
          findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(answers, [true]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('collection with one word says "1 word"', (tester) async {
      await pumpAsker(
        tester,
        (c) => confirmBin(
            c, const BinPreviewView(name: 'A', isFolder: false, wordCount: 1)),
      );
      expect(find.textContaining('1 word. It goes'), findsOneWidget);
    });

    testWidgets('folder: counts collections and folders', (tester) async {
      await pumpAsker(
        tester,
        (c) => confirmBin(
            c,
            const BinPreviewView(
                name: 'English course', isFolder: true, collections: 3, folders: 1)),
      );
      expect(find.text('Delete "English course"?'), findsOneWidget);
      expect(find.text('3 collections and 1 folder go to the recycle bin with it, for 30 days.'),
          findsOneWidget);
    });

    testWidgets('folder pluralisation variants', (tester) async {
      expect(binBodyText(const BinPreviewView(name: 'F', isFolder: true, collections: 1)),
          '1 collection goes to the recycle bin with it, for 30 days.');
      expect(
          binBodyText(
              const BinPreviewView(name: 'F', isFolder: true, collections: 2, folders: 2)),
          '2 collections and 2 folders go to the recycle bin with it, for 30 days.');
      expect(binBodyText(const BinPreviewView(name: 'F', isFolder: true, folders: 1)),
          '1 folder goes to the recycle bin with it, for 30 days.');
      expect(binBodyText(const BinPreviewView(name: 'F', isFolder: true)),
          'It goes to the recycle bin for 30 days.');
    });

    testWidgets('folder with current names it as staying; Cancel returns false',
        (tester) async {
      final answers = await pumpAsker(
        tester,
        (c) => confirmBin(
            c,
            const BinPreviewView(
                name: 'English course',
                isFolder: true,
                collections: 3,
                folders: 1,
                currentStaysName: 'Lesson 4')),
      );
      expect(
          find.text('3 collections and 1 folder go to the recycle bin with it, for 30 days. '
              '"Lesson 4" stays, because it is the current collection. '
              'It moves to where this folder is.'),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });

    testWidgets('a tap outside returns false', (tester) async {
      final answers = await pumpAsker(
        tester,
        (c) => confirmBin(c, const BinPreviewView(name: 'L', isFolder: false)),
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });
  });

  group('SCR-04 snack texts', () {
    test('refused current, stayed, restored', () {
      expect(refusedCurrentText,
          'The current collection cannot be deleted. Open another collection first.');
      expect(stayedText('Lesson 4'),
          'Lesson 4 stayed here because it is the current collection.');
      expect(restoredText('Unit 3'), 'Restored to Unit 3');
      expect(restoredText(null), 'Restored to Collections');
    });
  });

  group('SCR-10 confirmEraseForever / confirmEmptyBin', () {
    const shared =
        'Its shared page stays online until it expires, and can no longer be updated from the app.';

    testWidgets('one item: cannot be undone, Delete forever returns true', (tester) async {
      final answers = await pumpAsker(
          tester, (c) => confirmEraseForever(c, name: 'Lesson 2', anyShared: false));
      expect(find.text('Delete "Lesson 2" forever?'), findsOneWidget);
      expect(find.text('This cannot be undone. Its words and photos are erased from the phone.'),
          findsOneWidget);
      expect(find.textContaining(shared), findsNothing);
      await tester.tap(find.text('Delete forever'));
      await tester.pumpAndSettle();
      expect(answers, [true]);
    });

    testWidgets('one item with a shared link adds the shared-page sentence; Cancel false',
        (tester) async {
      final answers = await pumpAsker(
          tester, (c) => confirmEraseForever(c, name: 'Lesson 2', anyShared: true));
      expect(
          find.text('This cannot be undone. Its words and photos are erased from the phone. '
              '$shared'),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });

    testWidgets('empty the bin: count, Empty returns true', (tester) async {
      final answers = await pumpAsker(
          tester, (c) => confirmEmptyBin(c, itemCount: 3, anyShared: false));
      expect(find.text('Empty the recycle bin?'), findsOneWidget);
      expect(find.text('3 items are erased for good. This cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Empty'));
      await tester.pumpAndSettle();
      expect(answers, [true]);
    });

    testWidgets('empty the bin with shared and one item; Cancel false', (tester) async {
      final answers = await pumpAsker(
          tester, (c) => confirmEmptyBin(c, itemCount: 1, anyShared: true));
      expect(find.text('1 item is erased for good. This cannot be undone. $shared'),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });
  });

  group('BinDropZone', () {
    testWidgets('shows the text and icon; highlight changes the look; wrapper wraps',
        (tester) async {
      Future<Color?> colorOf(bool highlighted) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: BinDropZone(highlighted: highlighted)),
        ));
        final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
        return (box.decoration as BoxDecoration?)?.color;
      }

      final plain = await colorOf(false);
      expect(find.text(BinDropZone.label), findsOneWidget);
      expect(BinDropZone.label, 'Drop here to delete');
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      final lit = await colorOf(true);
      expect(lit, isNot(plain));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BinDropZone(
            wrapper: (context, zone) => KeyedSubtree(key: const Key('wrap'), child: zone),
          ),
        ),
      ));
      expect(
          find.descendant(of: find.byKey(const Key('wrap')), matching: find.text(BinDropZone.label)),
          findsOneWidget);
    });
  });

  group('SCR-08 RecycleBinList', () {
    testWidgets('loading', (tester) async {
      await pumpList(tester, null);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await pumpList(tester, const []);
      expect(find.text('The recycle bin is empty'), findsOneWidget);
      expect(RecycleBinList.emptyText, 'The recycle bin is empty');
    });

    testWidgets('default: name, words for collections, days left, in the given order',
        (tester) async {
      await pumpList(tester, const [lesson2, oldFilms, dated]);
      expect(find.text('Lesson 2'), findsOneWidget);
      expect(find.text('12 words'), findsOneWidget);
      expect(find.text('30 days left'), findsOneWidget);
      expect(find.text('Old films'), findsOneWidget);
      expect(find.text('7 days left'), findsOneWidget);
      expect(find.text('1 word'), findsOneWidget);
      expect(find.text('1 day left'), findsOneWidget);
      expect(find.text('0 words'), findsNothing); // folders show no word count
      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.byIcon(Icons.style), findsNWidgets(2));
      final y = [lesson2, oldFilms, dated]
          .map((i) => tester.getTopLeft(find.text(i.name)).dy)
          .toList();
      expect(y[0] < y[1] && y[1] < y[2], isTrue);
    });

    testWidgets('⋮ → Restore fires with the item', (tester) async {
      final restored = <BinItemView>[];
      await pumpList(tester, const [lesson2, oldFilms], onRestore: restored.add);
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Delete forever'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(restored, [oldFilms]);
    });

    testWidgets('a tap on the row opens the menu, never the collection; Delete forever fires',
        (tester) async {
      final erased = <BinItemView>[];
      await pumpList(tester, const [lesson2], onDeleteForever: erased.add);
      await tester.tap(find.text('Lesson 2'));
      await tester.pumpAndSettle();
      expect(find.text('Restore'), findsOneWidget);
      await tester.tap(find.text('Delete forever'));
      await tester.pumpAndSettle();
      expect(erased, [lesson2]);
    });

    testWidgets('a long press on the row opens the menu', (tester) async {
      await pumpList(tester, const [lesson2]);
      await tester.longPress(find.text('Lesson 2'));
      await tester.pumpAndSettle();
      expect(find.text('Restore'), findsOneWidget);
    });
  });

  group('EmptyBinAction', () {
    testWidgets('enabled fires; disabled does not', (tester) async {
      var taps = 0;
      Future<void> pump(bool enabled) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                title: const Text('Recycle bin'),
                actions: [EmptyBinAction(enabled: enabled, onPressed: () => taps++)],
              ),
            ),
          ));
      await pump(true);
      await tester.tap(find.text('Empty recycle bin'));
      expect(taps, 1);
      await pump(false);
      await tester.tap(find.text('Empty recycle bin'));
      expect(taps, 1);
    });
  });
}
