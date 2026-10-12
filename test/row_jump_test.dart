import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/row_jump.dart';

/// side-bar-for-main-screen T12: the jump to a photo's first row brings it
/// fully into view within 500 ms in a list of 200 rows of mixed heights,
/// moving as little as needed (spec AC-04; QG-2c).
void main() {
  double heightOf(int i) => 50.0 + (i * 37) % 90;

  late ScrollController scroll;
  late List<GlobalKey> keys;

  setUp(() {
    scroll = ScrollController();
    keys = List.generate(200, (_) => GlobalKey());
  });

  Widget row(int i) => SizedBox(key: keys[i], height: heightOf(i), child: Text('row $i'));

  Future<void> pumpList(WidgetTester tester, {bool dragMode = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: dragMode
            ? ReorderableListView.builder(
                scrollController: scroll,
                padding: const EdgeInsets.all(16),
                itemCount: 200,
                onReorder: (_, __) {},
                itemBuilder: (context, i) => row(i),
              )
            : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                itemCount: 200,
                itemBuilder: (context, i) => row(i),
              ),
      ),
    ));
  }

  /// Runs the jump while frames are pumped, for at most [budget].
  Future<void> jumpWithin(WidgetTester tester, int index,
      {Duration budget = const Duration(milliseconds: 500)}) async {
    var done = false;
    jumpToRow(scroll, index, (i) => i < keys.length ? keys[i] : null).then((_) => done = true);
    var spent = Duration.zero;
    const frame = Duration(milliseconds: 16);
    while (!done && spent < budget) {
      await tester.pump(frame);
      spent += frame;
    }
    expect(done, isTrue, reason: 'the jump finished within $budget');
  }

  void expectFullyInView(WidgetTester tester, int index) {
    final viewport = tester.getRect(find.byType(Scrollable).first);
    final r = tester.getRect(find.byKey(keys[index]));
    expect(r.top, greaterThanOrEqualTo(viewport.top - 0.5));
    expect(r.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
  }

  testWidgets('a row near the end comes fully into view within 500 ms', (tester) async {
    await pumpList(tester);
    await jumpWithin(tester, 185);
    expectFullyInView(tester, 185);
  });

  testWidgets('a row far down, then one far up, each come into view', (tester) async {
    await pumpList(tester);
    await jumpWithin(tester, 120);
    expectFullyInView(tester, 120);
    await jumpWithin(tester, 7);
    expectFullyInView(tester, 7);
  });

  testWidgets('moves as little as needed: the row ends at the bottom edge', (tester) async {
    await pumpList(tester);
    await jumpWithin(tester, 60);
    final viewport = tester.getRect(find.byType(Scrollable).first);
    expect(tester.getRect(find.byKey(keys[60])).bottom, closeTo(viewport.bottom, 1));
  });

  testWidgets('a row already in view does not move', (tester) async {
    await pumpList(tester);
    final before = tester.getRect(find.byKey(keys[2]));
    await jumpWithin(tester, 2);
    expect(scroll.offset, 0);
    expect(tester.getRect(find.byKey(keys[2])), before);
  });

  testWidgets('the drag-mode list jumps too', (tester) async {
    await pumpList(tester, dragMode: true);
    await jumpWithin(tester, 150);
    expectFullyInView(tester, 150);
  });

  testWidgets('a list with no position yet is left alone', (tester) async {
    await expectLater(jumpToRow(ScrollController(), 3, (i) => i < keys.length ? keys[i] : null), completes);
  });
}
