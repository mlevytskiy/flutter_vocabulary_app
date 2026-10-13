import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'package:flutter_vocabulary_app/core/providers.dart' show WordDetailMode;
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_a.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_morph.dart';

/// While the photo panel is open each word row turns into one line,
/// "word — translation" (or the definition), and back when it closes; look A
/// draws its tab and half-open panel on glass.
void main() {
  group('compactDetail', () {
    test('the translation when the mode shows one and it is filled', () {
      expect(
          compactDetail(
              mode: WordDetailMode.translation, translation: ' слово ', definition: 'a unit'),
          'слово');
      expect(
          compactDetail(mode: WordDetailMode.both, translation: 'слово', definition: 'a unit'),
          'слово');
    });

    test('the definition when there is no translation, or the mode has none', () {
      expect(
          compactDetail(mode: WordDetailMode.translation, translation: '  ', definition: 'a unit'),
          'a unit');
      expect(
          compactDetail(mode: WordDetailMode.both, translation: '', definition: 'a unit'),
          'a unit');
      expect(
          compactDetail(
              mode: WordDetailMode.definition, translation: 'слово', definition: 'a unit'),
          'a unit');
    });

    test('a definition on several lines becomes one line; nothing gives empty', () {
      expect(
          compactDetail(
              mode: WordDetailMode.definition, translation: '', definition: 'one\n  two\nthree'),
          'one two three');
      expect(compactDetail(mode: WordDetailMode.translation, translation: '', definition: ''),
          isEmpty);
    });
  });

  group('CompactWordLine', () {
    test('reads "word — detail", or whichever part there is', () {
      expect(const CompactWordLine(index: 0, word: 'run ', detail: 'бігти').text, 'run — бігти');
      expect(const CompactWordLine(index: 0, word: 'run', detail: '').text, 'run');
      expect(const CompactWordLine(index: 0, word: '', detail: 'бігти').text, 'бігти');
    });

    testWidgets('one line, cut with an ellipsis, ending before the panel', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: CompactWordLine(
              index: 0,
              word: 'serendipity',
              detail: 'щасливий збіг обставин, що трапляється зовсім випадково і несподівано',
              endInset: 96,
            ),
          ),
        ),
      ));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.getRect(find.byType(Text)).right, lessThanOrEqualTo(300 - 96 - 14));
      expect(tester.getSize(find.byType(CompactWordLine)).height, lessThan(64));
    });
  });

  group('WordRowMorph', () {
    const fullKey = Key('test-full-row');
    const lineKey = Key('test-line');

    Widget host({required bool compact, double top = 0}) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.only(top: top),
              child: Align(
                alignment: Alignment.topCenter,
                child: WordRowMorph(
                  index: 0,
                  compact: compact,
                  full: const SizedBox(key: fullKey, height: 140),
                  line: (reveal) => CompactWordLine(
                      key: lineKey, index: 0, word: 'run', detail: 'бігти', reveal: reveal),
                ),
              ),
            ),
          ),
        );

    double height(WidgetTester tester) => tester.getSize(find.byType(WordRowMorph)).height;

    testWidgets('glides from the full row to its line and back', (tester) async {
      await tester.pumpWidget(host(compact: false));
      expect(find.byKey(fullKey), findsOneWidget);
      expect(find.byKey(lineKey), findsNothing);
      expect(height(tester), 140);

      await tester.pumpWidget(host(compact: true));
      await tester.pump(); // the row's turn starts after this frame
      await tester.pump(); // a row at the top has no wait
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(fullKey), findsOneWidget, reason: 'the full row fades out');
      expect(find.byKey(lineKey), findsOneWidget, reason: 'the line fades in');
      expect(height(tester), inExclusiveRange(56, 140), reason: 'the card glides');

      await tester.pumpAndSettle();
      expect(find.byKey(fullKey), findsNothing);
      expect(tester.widget<CompactWordLine>(find.byKey(lineKey)).reveal, isTrue);
      final lineHeight = height(tester);
      expect(lineHeight, lessThan(70));

      await tester.pumpWidget(host(compact: false));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(height(tester), inExclusiveRange(lineHeight, 140));
      await tester.pumpAndSettle();
      expect(find.byKey(fullKey), findsOneWidget);
      expect(find.byKey(lineKey), findsNothing);
      expect(height(tester), 140);
    });

    testWidgets('closing again mid-morph keeps one field per controller in the end',
        (tester) async {
      final controller = TextEditingController(text: 'run');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      Widget withField(bool compact) => MaterialApp(
            home: Scaffold(
              body: WordRowMorph(
                index: 0,
                compact: compact,
                full: TextField(controller: controller, focusNode: focus),
                line: (reveal) =>
                    CompactWordLine(index: 0, word: 'run', detail: '', reveal: reveal),
              ),
            ),
          );
      await tester.pumpWidget(withField(false));
      await tester.pumpWidget(withField(true));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(withField(false));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CompactWordLine), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('built while compact, it is a line at once, with no reveal', (tester) async {
      await tester.pumpWidget(host(compact: true));
      expect(find.byKey(lineKey), findsOneWidget);
      expect(find.byKey(fullKey), findsNothing);
      expect(tester.widget<CompactWordLine>(find.byKey(lineKey)).reveal, isFalse);
    });

    testWidgets('a rebuild that changes nothing does not animate', (tester) async {
      await tester.pumpWidget(host(compact: true));
      await tester.pumpWidget(host(compact: true));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(await tester.pumpAndSettle(), 1);
    });

    testWidgets('a row lower on the screen takes its turn later (the wave)', (tester) async {
      await tester.pumpWidget(host(compact: false, top: 500));
      await tester.pumpWidget(host(compact: true, top: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(lineKey), findsNothing, reason: 'still waiting for its turn');
      await tester.pumpAndSettle();
      expect(find.byKey(lineKey), findsOneWidget);
    });
  });

  group('look A glass', () {
    testWidgets('the tab and the half-open panel stand on glass; full-open is dark',
        (tester) async {
      const look = LookA();
      Widget panel(double fullness) => MaterialApp(
            home: Builder(
              builder: (context) => SizedBox(
                width: look.halfOpenWidth,
                height: 400,
                child: look.buildPanelSurface(context,
                    fullness: fullness, child: const Text('content')),
              ),
            ),
          );

      await tester.pumpWidget(panel(0));
      expect(find.byType(LiquidGlass), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      expect(
          find.ancestor(of: find.text('content'), matching: find.byType(Material)), findsWidgets,
          reason: 'the controls get their ink');

      await tester.pumpWidget(panel(1));
      expect(find.byType(LiquidGlass), findsNothing);
      expect(
          tester.widgetList<ColoredBox>(find.byType(ColoredBox)).map((b) => b.color),
          contains(Colors.black));

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => look.buildTab(context,
              photos: const [], preview: (_, __) => const SizedBox()),
        ),
      ));
      expect(find.byType(LiquidGlass), findsOneWidget);
    });
  });
}
