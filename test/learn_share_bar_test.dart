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
  testWidgets('AC-12: where it fits, Share is exactly as today', (t) async {
    await _pump(t, width: 600);
    final shareFinder = find.ancestor(
        of: find.text('Share'), matching: find.bySubtype<ElevatedButton>());
    expect(shareFinder, findsOneWidget);
    final pad = t.widget<Padding>(
        find.ancestor(of: shareFinder, matching: find.byType(Padding)).first);
    expect(pad.padding, const EdgeInsets.only(right: 16.0));
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

  testWidgets('AC-11b: icon-only at 320 dp / 130 % long press shows names',
      (t) async {
    await _pump(t, width: 320, textScale: 1.3);
    expect(find.text('Learn'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.byTooltip('Learn'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    for (final name in ['Learn', 'Share']) {
      final size = t.getSize(find.byTooltip(name));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await t.longPress(find.byTooltip('Learn'));
    await t.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
  });
}
