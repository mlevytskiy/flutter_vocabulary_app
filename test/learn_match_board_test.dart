import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/learn/kit/match_board.dart';

/// learn-match-synonyms: the kit match board (S-35..S-37; AC-04..AC-08,
/// AC-13, AC-14, AC-24). The board is driven here by a caller that is not
/// an exercise, with its own right-pair rule, to show it never decides.
void main() {
  group('cardText (S-37, D-10)', () {
    test('AC-13: text up to 120 characters is unchanged', () {
      final t = 'a' * 120;
      expect(cardText(t), t);
      expect(cardText('large'), 'large');
    });

    test('AC-13: longer text is cut at the end of its first sentence when that fits', () {
      final t = 'A big animal that lives in the sea. ${'It swims very far and eats a lot of small fish every day ' * 3}';
      expect(cardText(t), 'A big animal that lives in the sea.');
    });

    test('AC-13: else at the last whole word within 120 plus "…"', () {
      final t = List.filled(40, 'word').join(' '); // 199 chars, no sentence end
      final cut = cardText(t);
      expect(cut.endsWith('…'), isTrue);
      final body = cut.substring(0, cut.length - 1);
      expect(body.length, lessThanOrEqualTo(120));
      expect(t.startsWith(body), isTrue);
      expect(body.endsWith('word'), isTrue);
      expect(cardText('x' * 130).length, 121, reason: 'one long word is cut at 120');
    });
  });

  test('missesText (S-37)', () {
    expect(missesText(0), 'no misses');
    expect(missesText(1), '1 miss');
    expect(missesText(3), '3 misses');
  });

  group('MatchBoard', () {
    const left = [
      MatchItem(id: 'a', text: 'big', hint: 'великий'),
      MatchItem(id: 'b', text: 'car'),
      MatchItem(id: 'c', text: 'dog', hint: 'пес'),
    ];
    const right = [
      MatchItem(id: 'c', text: 'hound'),
      MatchItem(id: 'a', text: 'large'),
      MatchItem(id: 'b', text: 'automobile'),
    ];

    late Map<String, String> links;
    late List<(String, String)> calls;
    late int misses;

    // The caller's own rule (S-38 uses leftId == rightId; this one is a table).
    bool Function(String, String) caller(StateSetter setState, Map<String, String> rule) => (l, r) {
          calls.add((l, r));
          if (rule[l] == r) {
            setState(() => links = {...links, l: r});
            return true;
          }
          misses++;
          return false;
        };

    Future<void> pump(WidgetTester tester,
        {List<MatchItem> l = left, List<MatchItem> r = right, Map<String, String>? rule}) async {
      links = {};
      calls = [];
      misses = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MatchBoard(
              left: l,
              right: r,
              links: links,
              onPair: caller(setState, rule ?? {for (final x in l) x.id: x.id}),
            ),
          ),
        ),
      ));
    }

    Finder leftCard(String id) => find.byKey(ValueKey('match-left-$id'));
    Finder rightCard(String id) => find.byKey(ValueKey('match-right-$id'));

    bool isSelected(WidgetTester tester, Finder card) =>
        tester.widget<MatchCard>(card).selected;

    double shakeOf(WidgetTester tester, Finder card) {
      final t = tester.widget<Transform>(find.descendant(of: card, matching: find.byType(Transform)).first);
      return t.transform.getTranslation().x.abs();
    }

    testWidgets('AC-02: both columns in the order given', (tester) async {
      await pump(tester);
      final ys = [for (final id in ['a', 'b', 'c']) tester.getTopLeft(leftCard(id)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      final rs = [for (final id in ['c', 'a', 'b']) tester.getTopLeft(rightCard(id)).dy];
      expect(rs, orderedEquals([...rs]..sort()));
      expect(tester.getTopLeft(leftCard('a')).dx, lessThan(tester.getTopLeft(rightCard('a')).dx));
    });

    testWidgets('AC-04: word then its synonym calls onPair once; both cards show "1" and ignore later taps', (tester) async {
      await pump(tester);
      await tester.tap(leftCard('a'));
      await tester.pump();
      expect(isSelected(tester, leftCard('a')), isTrue);
      await tester.tap(rightCard('a'));
      await tester.pump();
      expect(calls, [('a', 'a')]);
      expect(misses, 0);
      expect(find.descendant(of: leftCard('a'), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: rightCard('a'), matching: find.text('1')), findsOneWidget);
      expect(tester.widget<MatchCard>(leftCard('a')).pairNumber, 1);
      await tester.tap(leftCard('a'));
      await tester.tap(rightCard('b'));
      await tester.pump();
      expect(calls, [('a', 'a')], reason: 'a locked card ignores taps');
      expect(isSelected(tester, leftCard('a')), isFalse);
      expect(isSelected(tester, rightCard('b')), isTrue);
    });

    testWidgets('AC-05: synonym first, then its word; the second pair shows "2"', (tester) async {
      await pump(tester);
      await tester.tap(rightCard('a'));
      await tester.tap(leftCard('a'));
      await tester.pump();
      expect(calls, [('a', 'a')]);
      await tester.tap(rightCard('c'));
      await tester.tap(leftCard('c'));
      await tester.pump();
      expect(find.descendant(of: leftCard('c'), matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: rightCard('c'), matching: find.text('2')), findsOneWidget);
    });

    testWidgets('AC-06: a wrong pair shakes both cards once, unselects them, counts each try', (tester) async {
      await pump(tester);
      await tester.tap(leftCard('a'));
      await tester.tap(rightCard('b'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(calls, [('a', 'b')]);
      expect(misses, 1);
      expect(shakeOf(tester, leftCard('a')), greaterThan(0));
      expect(shakeOf(tester, rightCard('b')), greaterThan(0));
      expect(shakeOf(tester, leftCard('b')), 0);
      expect(isSelected(tester, leftCard('a')), isFalse);
      expect(isSelected(tester, rightCard('b')), isFalse);
      await tester.pumpAndSettle();
      expect(shakeOf(tester, leftCard('a')), 0);
      await tester.tap(leftCard('a'));
      await tester.tap(rightCard('c'));
      await tester.pumpAndSettle();
      expect(misses, 2);
      expect(links, isEmpty);
    });

    testWidgets('AC-07: tapping the selected card unselects it; another in the same column moves the selection', (tester) async {
      await pump(tester);
      await tester.tap(leftCard('a'));
      await tester.pump();
      await tester.tap(leftCard('a'));
      await tester.pump();
      expect(isSelected(tester, leftCard('a')), isFalse);
      await tester.tap(rightCard('a'));
      await tester.tap(rightCard('b'));
      await tester.pump();
      expect(isSelected(tester, rightCard('a')), isFalse);
      expect(isSelected(tester, rightCard('b')), isTrue);
      expect(calls, isEmpty);
      expect(misses, 0);
    });

    testWidgets('AC-08: the last pair locks visibly', (tester) async {
      await pump(tester);
      for (final id in ['a', 'b', 'c']) {
        await tester.tap(leftCard(id));
        await tester.tap(rightCard(id));
        await tester.pump();
      }
      expect(links.length, 3);
      for (final n in ['1', '2', '3']) {
        expect(find.text(n), findsNWidgets(2));
      }
    });

    testWidgets('AC-14: long press on a card with a hint shows it and changes nothing; no hint shows nothing', (tester) async {
      await pump(tester);
      await tester.longPress(leftCard('a'));
      await tester.pump();
      expect(find.text('великий'), findsOneWidget);
      expect(isSelected(tester, leftCard('a')), isFalse);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.longPress(leftCard('b'));
      await tester.longPress(rightCard('a'));
      await tester.pump();
      expect(find.text('великий'), findsNothing);
      expect(calls, isEmpty);
      // A long press keeps an existing selection.
      await tester.tap(rightCard('a'));
      await tester.pump();
      await tester.longPress(leftCard('c'));
      await tester.pump();
      expect(find.text('пес'), findsOneWidget);
      expect(isSelected(tester, rightCard('a')), isTrue);
      expect(calls, isEmpty);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('AC-13: long text wraps (never ellipsised) and the board scrolls', (tester) async {
      tester.view.physicalSize = const Size(360, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final long = cardText('a definition of the word that runs on and on ' * 2);
      final l = [for (var i = 0; i < 6; i++) MatchItem(id: '$i', text: 'word$i')];
      final r = [for (var i = 5; i >= 0; i--) MatchItem(id: '$i', text: '$long $i')];
      await pump(tester, l: l, r: r);
      final text = tester.widget<Text>(find.descendant(of: rightCard('0'), matching: find.byType(Text)).first);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.getSize(rightCard('0')).height, greaterThan(tester.getSize(leftCard('0')).height / 2));
      expect(find.byType(Scrollable), findsOneWidget, reason: 'one list for both columns');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(leftCard('5'), 100);
      await tester.tap(leftCard('5'));
      await tester.pump();
      expect(isSelected(tester, leftCard('5')), isTrue);
    });

    testWidgets('AC-24: definitions with a different right-pair rule; the board follows the caller', (tester) async {
      const l = [
        MatchItem(id: 'w1', text: 'cat'),
        MatchItem(id: 'w2', text: 'dog'),
        MatchItem(id: 'w3', text: 'cow'),
      ];
      const r = [
        MatchItem(id: 'd3', text: 'A farm animal that gives milk.'),
        MatchItem(id: 'd1', text: 'A small animal that says meow.'),
        MatchItem(id: 'd2', text: 'An animal that barks.'),
      ];
      await pump(tester, l: l, r: r, rule: {'w1': 'd1', 'w2': 'd2', 'w3': 'd3'});
      await tester.tap(leftCard('w1'));
      await tester.tap(rightCard('d1'));
      await tester.pump();
      expect(links, {'w1': 'd1'});
      expect(find.descendant(of: rightCard('d1'), matching: find.text('1')), findsOneWidget);
      await tester.tap(rightCard('d3'));
      await tester.tap(leftCard('w2'));
      await tester.pumpAndSettle();
      expect(misses, 1);
      expect(calls.last, ('w2', 'd3'));
    });
  });
}
