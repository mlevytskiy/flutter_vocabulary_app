import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/learn/kit/choice_options.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/question_builder.dart';

/// learn-pick-the-answer S-28: the shared choice widget (AC-05, AC-06, AC-20).
void main() {
  const q = Question(rowId: 'r', prompt: 'cat', options: ['пес', 'кіт', 'птах', 'риба'], rightIndex: 1);

  Color? colorOf(WidgetTester tester, int i) {
    final b = tester.widget<ElevatedButton>(find.byKey(ValueKey('option-$i')));
    return b.style?.backgroundColor?.resolve({});
  }

  Future<void> pump(WidgetTester tester, {int? picked, bool reveal = true, required List<int> taps, Question question = q}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ChoiceOptions(question: question, picked: picked, reveal: reveal, onPick: taps.add)),
    ));
  }

  testWidgets('four full-width buttons; a tap reports its index once, later taps are ignored', (tester) async {
    final taps = <int>[];
    await pump(tester, taps: taps);
    expect(find.byType(ElevatedButton), findsNWidgets(4));
    await tester.tap(find.text('птах'));
    await tester.tap(find.text('риба'));
    await tester.pump();
    expect(taps, [2]);
  });

  testWidgets('nothing is marked before a pick', (tester) async {
    await pump(tester, taps: []);
    for (var i = 0; i < 4; i++) {
      expect(colorOf(tester, i), isNull);
    }
  });

  testWidgets('reveal: the right option is green; a wrong pick is red', (tester) async {
    await pump(tester, picked: 1, taps: []);
    expect(colorOf(tester, 1), Colors.green);
    expect(colorOf(tester, 0), isNull);
    await pump(tester, picked: 0, taps: []);
    expect(colorOf(tester, 0), Colors.red);
    expect(colorOf(tester, 1), Colors.green);
    expect(colorOf(tester, 2), isNull);
  });

  testWidgets('no reveal: only the picked option is marked, neither green nor red', (tester) async {
    await pump(tester, picked: 0, reveal: false, taps: []);
    expect(colorOf(tester, 1), isNull);
    expect(colorOf(tester, 0), isNotNull);
    expect(colorOf(tester, 0), isNot(Colors.green));
    expect(colorOf(tester, 0), isNot(Colors.red));
  });

  testWidgets('after a pick (given by the parent) a tap does nothing', (tester) async {
    final taps = <int>[];
    await pump(tester, picked: 0, taps: taps);
    await tester.tap(find.text('птах'));
    expect(taps, isEmpty);
  });

  testWidgets('AC-20: a long option wraps and is not cut', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final long = 'A very long definition. ' * 6;
    await pump(tester, taps: [], question: Question(rowId: 'r', prompt: 'p', options: [long.trim(), 'a', 'b', 'c'], rightIndex: 0));
    final t = tester.widget<Text>(find.text(long.trim()));
    expect(t.overflow, isNot(TextOverflow.ellipsis));
    expect(t.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });
}
