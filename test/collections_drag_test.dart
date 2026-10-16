import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/collections/bin_drop_zone.dart';
import 'package:flutter_vocabulary_app/features/collections/collection_drag.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_view.dart';

// Tree: top level holds folder "en" (English course), folder "fr" and
// collections c1, c2. "en" holds folder "u3" (Unit 3), which holds "deep".
const _parentOf = <String, String?>{'en': null, 'fr': null, 'u3': 'en', 'deep': 'u3'};
const _en = CollectionItemView(id: 'en', isFolder: true, name: 'English course');
const _fr = CollectionItemView(id: 'fr', isFolder: true, name: 'French');
const _c1 = CollectionItemView(id: 'c1', isFolder: false, name: 'Lesson 1', wordCount: 3);
const _c2 = CollectionItemView(id: 'c2', isFolder: false, name: 'Lesson 2', wordCount: 5);
const _top = ['en', 'fr', 'c1', 'c2'];

DropDecision onTop(CollectionItemView dragged, DropTarget target) => decideDrop(
      dragged: dragged,
      target: target,
      openFolderId: null,
      parentOf: _parentOf,
      levelIds: _top,
    );

void main() {
  group('decideDrop', () {
    test('folder icon moves the item into it', () {
      expect(onTop(_c1, const FolderIconTarget('en')), const MoveInto('en'));
      expect(onTop(_fr, const FolderIconTarget('en')), const MoveInto('en'));
    });

    test('a folder onto itself or a descendant is refused', () {
      expect(onTop(_en, const FolderIconTarget('en')), const RefusedIntoItself());
      expect(
        decideDrop(
          dragged: _en,
          target: const FolderIconTarget('deep'),
          openFolderId: 'u3',
          parentOf: _parentOf,
          levelIds: const ['deep'],
          fromFolderId: null,
        ),
        const RefusedIntoItself(),
      );
      expect(RefusedIntoItself.message, 'A folder cannot go inside itself');
    });

    test('another collection icon reorders to its place', () {
      expect(onTop(_c1, const CollectionIconTarget('c2')), const Reorder(3));
      expect(onTop(_c2, const CollectionIconTarget('c1')), const Reorder(2));
      expect(onTop(_en, const CollectionIconTarget('c2')), const Reorder(3));
    });

    test('own collection icon does nothing', () {
      expect(onTop(_c1, const CollectionIconTarget('c1')), const NoOp());
    });

    test('a gap reorders, its own gaps do nothing', () {
      expect(onTop(_c2, const GapTarget(0)), const Reorder(0));
      expect(onTop(_en, const GapTarget(4)), const Reorder(3));
      expect(onTop(_en, const GapTarget(2)), const Reorder(1));
      expect(onTop(_c1, const GapTarget(2)), const NoOp());
      expect(onTop(_c1, const GapTarget(3)), const NoOp());
    });

    test('Up moves to the parent level; at the top level it does nothing', () {
      expect(onTop(_c1, const UpTarget()), const NoOp());
      expect(
        decideDrop(
          dragged: const CollectionItemView(id: 'x', isFolder: false, name: 'X'),
          target: const UpTarget(),
          openFolderId: 'u3',
          parentOf: _parentOf,
          levelIds: const ['deep', 'x'],
        ),
        const MoveInto('en'),
      );
    });

    test('Up from a hover-opened folder back to the own level does nothing', () {
      expect(
        decideDrop(
          dragged: _c1,
          target: const UpTarget(),
          openFolderId: 'en',
          parentOf: _parentOf,
          levelIds: const ['u3'],
          fromFolderId: null,
        ),
        const NoOp(),
      );
    });

    test('path part moves there; the own folder part does nothing', () {
      const x = CollectionItemView(id: 'x', isFolder: false, name: 'X');
      DropDecision inU3(DropTarget t) => decideDrop(
            dragged: x,
            target: t,
            openFolderId: 'u3',
            parentOf: _parentOf,
            levelIds: const ['deep', 'x'],
          );
      expect(inU3(const PathPartTarget(null)), const MoveInto(null));
      expect(inU3(const PathPartTarget('en')), const MoveInto('en'));
      expect(inU3(const PathPartTarget('u3')), const NoOp());
      expect(onTop(_c1, const PathPartTarget(null)), const NoOp());
    });

    test('after hover-open, the open level part, gaps and icons move it in', () {
      DropDecision inEn(DropTarget t) => decideDrop(
            dragged: _c1,
            target: t,
            openFolderId: 'en',
            parentOf: _parentOf,
            levelIds: const ['u3'],
            fromFolderId: null,
          );
      expect(inEn(const PathPartTarget('en')), const MoveInto('en'));
      expect(inEn(const GapTarget(1)), const MoveInto('en', at: 1));
      expect(inEn(const PathPartTarget(null)), const NoOp());
    });

    test('a folder moved by path into its own subtree is refused', () {
      expect(
        decideDrop(
          dragged: _en,
          target: const PathPartTarget('u3'),
          openFolderId: 'deep',
          parentOf: _parentOf,
          levelIds: const [],
          fromFolderId: null,
        ),
        const RefusedIntoItself(),
      );
    });

    test('bin and empty spot', () {
      expect(onTop(_c1, const BinTarget()), const ToBin());
      expect(onTop(_en, const BinTarget()), const ToBin());
      expect(onTop(_c1, const EmptySpotTarget()), const NoOp());
    });
  });

  group('drag widgets', () {
    late List<DropDecision> decisions;
    late List<String?> hoverOpened;
    late int noMove;

    setUp(() {
      decisions = [];
      hoverOpened = [];
      noMove = 0;
    });

    const level = CollectionDragLevel(openFolderId: null, parentOf: _parentOf, levelIds: _top);

    Widget icon(CollectionItemView item, Widget child) => DraggableCollectionIcon(
          item: item,
          level: level,
          onDecision: decisions.add,
          onHoverOpen: hoverOpened.add,
          onLongPressNoMove: () => noMove++,
          child: child,
        );

    Future<void> pumpScreen(WidgetTester t, {List<PathPart>? parts}) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            CollectionsPathBar(
              parts: parts ?? const [PathPart(null, 'Collections')],
              upEnabled: false,
              onUp: () {},
              onPart: (_) {},
              upWrapper: (c, child) =>
                  UpDropTarget(level: level, onDecision: decisions.add, child: child),
              partWrapper: (c, part, child) => PathPartDropTarget(
                part: part,
                level: level,
                onDecision: decisions.add,
                onHoverOpen: hoverOpened.add,
                child: child,
              ),
            ),
            CollectionGapTarget(
              index: 0,
              level: level,
              onDecision: decisions.add,
              child: const SizedBox(key: Key('gap0'), height: 30, width: 300),
            ),
            SizedBox(
              height: 400,
              child: CollectionsGrid(
                items: const [_en, _fr, _c1, _c2],
                onTap: (_) {},
                onMenu: (_) {},
                showBin: true,
                itemWrapper: (c, item, child) => icon(item, child),
                binWrapper: (c, bin) =>
                    BinDropTarget(level: level, onDecision: decisions.add, child: bin),
              ),
            ),
          ]),
        ),
      ));
    }

    Future<TestGesture> grab(WidgetTester t, String name) async {
      final g = await t.startGesture(t.getCenter(find.text(name)));
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      return g;
    }

    Future<void> dragTo(WidgetTester t, String name, Finder target) async {
      final g = await grab(t, name);
      await g.moveBy(const Offset(20, 20));
      await t.pump();
      await g.moveTo(t.getCenter(target));
      await t.pump();
      await g.up();
      await t.pump();
    }

    testWidgets('drop on a folder icon moves into it', (t) async {
      await pumpScreen(t);
      await dragTo(t, 'Lesson 1', find.text('French'));
      expect(decisions, [const MoveInto('fr')]);
    });

    testWidgets('a folder dropped on itself is refused', (t) async {
      await pumpScreen(t);
      final g = await grab(t, 'English course');
      await g.moveBy(const Offset(60, 0));
      await t.pump();
      await g.moveBy(const Offset(-60, 0));
      await t.pump();
      await g.up();
      await t.pump();
      expect(decisions, [const RefusedIntoItself()]);
      expect(noMove, 0);
    });

    testWidgets('drop on another collection reorders', (t) async {
      await pumpScreen(t);
      await dragTo(t, 'Lesson 1', find.text('Lesson 2'));
      expect(decisions, [const Reorder(3)]);
    });

    testWidgets('drop on a gap reorders', (t) async {
      await pumpScreen(t);
      await dragTo(t, 'Lesson 2', find.byKey(const Key('gap0')));
      expect(decisions, [const Reorder(0)]);
    });

    testWidgets('drop on Up at the top level does nothing', (t) async {
      await pumpScreen(t);
      await dragTo(t, 'Lesson 1', find.text('Up'));
      expect(decisions, [const NoOp()]);
    });

    testWidgets('drop on the own level path part does nothing', (t) async {
      await pumpScreen(t);
      await dragTo(t, 'Lesson 1', find.text('Collections'));
      expect(decisions, [const NoOp()]);
    });

    testWidgets('drop on the bin icon bins', (t) async {
      await pumpScreen(t);
      await dragTo(t, 'Lesson 1', find.text('Recycle bin'));
      expect(decisions, [const ToBin()]);
    });

    testWidgets('drop on BinDropZone bins', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            SizedBox(width: 110, height: 160, child: icon(_c1, const Text('Lesson 1'))),
            const SizedBox(height: 100),
            BinDropTarget(
              level: level,
              onDecision: decisions.add,
              builder: (c, highlighted) => BinDropZone(highlighted: highlighted),
            ),
          ]),
        ),
      ));
      await dragTo(t, 'Lesson 1', find.text(BinDropZone.label));
      expect(decisions, [const ToBin()]);
    });

    testWidgets('drop on an empty spot does nothing', (t) async {
      await pumpScreen(t);
      final g = await grab(t, 'Lesson 1');
      await g.moveTo(const Offset(780, 590));
      await t.pump();
      await g.up();
      await t.pump();
      expect(decisions, [const NoOp()]);
    });

    testWidgets('long press released without moving opens the menu, no decision', (t) async {
      await pumpScreen(t);
      final g = await grab(t, 'English course');
      await g.up();
      await t.pump();
      expect(noMove, 1);
      expect(decisions, isEmpty);
    });

    testWidgets('holding over a folder for 1 s opens it', (t) async {
      await pumpScreen(t);
      final g = await grab(t, 'Lesson 1');
      await g.moveTo(t.getCenter(find.text('French')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 900));
      expect(hoverOpened, isEmpty);
      await t.pump(const Duration(milliseconds: 200));
      expect(hoverOpened, ['fr']);
      await g.up();
      await t.pump();
    });

    testWidgets('leaving a folder before 1 s does not open it', (t) async {
      await pumpScreen(t);
      final g = await grab(t, 'Lesson 1');
      await g.moveTo(t.getCenter(find.text('French')));
      await t.pump(const Duration(milliseconds: 600));
      await g.moveTo(const Offset(780, 590));
      await t.pump(const Duration(seconds: 2));
      expect(hoverOpened, isEmpty);
      await g.up();
      await t.pump();
    });

    testWidgets('the dragged folder over itself does not hover-open', (t) async {
      await pumpScreen(t);
      final g = await grab(t, 'English course');
      await g.moveBy(const Offset(30, 0));
      await t.pump(const Duration(seconds: 2));
      expect(hoverOpened, isEmpty);
      await g.up();
      await t.pump();
    });

    testWidgets('holding over a path part for 1 s opens it', (t) async {
      await pumpScreen(t, parts: const [PathPart(null, 'Collections'), PathPart('en', 'English course')]);
      final g = await grab(t, 'Lesson 1');
      await g.moveTo(t.getCenter(find.text('English course').first));
      await t.pump(const Duration(milliseconds: 1100));
      expect(hoverOpened, ['en']);
      await g.up();
      await t.pump();
    });
  });
}
