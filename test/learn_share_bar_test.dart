import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/words_table/widgets/learn_share_bar.dart';

// The test font (Ahem) is about twice as wide as Roboto, so the text is halved
// on top of the scale under test to give the widths a phone really has.
const _fontFactor = 0.5;

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double textScale = 1.0,
  VoidCallback? onLearn,
  VoidCallback? onShare,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: const Scaffold(body: Text('root')),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale * _fontFactor),
        ),
        child: child!,
      ),
    ),
  );
  final nav = tester.state<NavigatorState>(find.byType(Navigator));
  nav.push(MaterialPageRoute<void>(
    builder: (_) => Scaffold(
      appBar: LearnShareBar(
        title: 'Words',
        onLearn: onLearn ?? () {},
        onShare: onShare ?? () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'AC-12: Words centred, Learn and Share centred in the space beside it',
      (t) async {
    await _pump(t, width: 600);
    final shareFinder = find.ancestor(
        of: find.text('Share'), matching: find.bySubtype<ElevatedButton>());
    final learnFinder = find.ancestor(
        of: find.text('Learn'), matching: find.bySubtype<ElevatedButton>());
    expect(shareFinder, findsOneWidget);
    final words = t.getRect(find.text('Words'));
    expect(words.center.dx, closeTo(300, 0.5));
    // Arrow 56 on the left; Share's space runs to the right edge. Words keeps
    // a little measuring slack either side, hence the 2.5 tolerance.
    expect(
        t.getRect(learnFinder).center.dx, closeTo((56 + words.left) / 2, 2.5));
    expect(t.getRect(shareFinder).center.dx,
        closeTo((words.right + 600) / 2, 2.5));
    final btn = t.widget<ElevatedButton>(shareFinder);
    final style = btn.style!;
    expect(style.backgroundColor?.resolve({}), Colors.white);
    expect(find.descendant(of: shareFinder, matching: find.byIcon(Icons.share)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.text('Learn'),
                matching: find.bySubtype<ElevatedButton>()),
            matching: find.byIcon(Icons.school)),
        findsOneWidget);
    // Order: Learn, Words, Share
    final learnX = t.getCenter(find.text('Learn')).dx;
    final wordsX = t.getCenter(find.text('Words')).dx;
    final shareX = t.getCenter(find.text('Share')).dx;
    expect(learnX < wordsX && wordsX < shareX, isTrue);
  });

  testWidgets('AC-01: taps call the callbacks', (t) async {
    var l = 0, s = 0;
    await _pump(t, width: 600, onLearn: () => l++, onShare: () => s++);
    await t.tap(find.text('Learn'));
    await t.tap(find.text('Share'));
    expect([l, s], [1, 1]);
  });

  testWidgets('360 dp / 100 %: labels shown', (t) async {
    await _pump(t, width: 360);
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Words'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final width in [600.0, 360.0, 320.0]) {
    testWidgets('$width dp: Learn is drawn as tall as Share', (t) async {
      await _pump(t, width: width, textScale: width == 320 ? 1.3 : 1.0);
      double drawn(String name) {
        final tip = find.byTooltip(name);
        final material = tip.evaluate().isNotEmpty
            ? find.descendant(of: tip, matching: find.byType(Material))
            : find.ancestor(
                of: find.text(name), matching: find.byType(Material));
        return t.getSize(material.first).height;
      }

      expect(drawn('Learn'), drawn('Share'));
    });
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('320 dp / $scale: no overflow, Words whole, buttons >= 48',
        (t) async {
      await _pump(t, width: 320, textScale: scale);
      expect(t.takeException(), isNull);
      final words = find.text('Words');
      expect(words, findsOneWidget);
      final text = t.widget<Text>(words);
      expect(text.overflow, isNull);
      final box = t.renderObject<RenderBox>(words);
      final painter = TextPainter(
        text: TextSpan(
            text: 'Words',
            style:
                DefaultTextStyle.of(t.element(words)).style.merge(text.style)),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(scale * _fontFactor),
      )..layout();
      expect(box.size.width, greaterThanOrEqualTo(painter.width - 0.5));
      for (final b in find.bySubtype<ElevatedButton>().evaluate()) {
        final size = (b.renderObject! as RenderBox).size;
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      // Tap targets (hit area) are >= 48 x 48.
      for (final name in ['Learn', 'Share']) {
        final finder = find.byTooltip(name).evaluate().isNotEmpty
            ? find.byTooltip(name)
            : find.text(name);
        expect(finder, findsOneWidget);
      }
    });
  }

  testWidgets(
      'AC-11b: at 320 dp / 130 % Learn goes icon-only, Share keeps its label',
      (t) async {
    await _pump(t, width: 320, textScale: 1.3);
    expect(find.text('Learn'), findsNothing);
    expect(find.byTooltip('Learn'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    final size = t.getSize(find.byTooltip('Learn'));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await t.longPress(find.byTooltip('Learn'));
    await t.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
  });
}
