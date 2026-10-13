import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/providers.dart' show WordDetailMode;
import 'package:flutter_vocabulary_app/core/widgets/synced_text_field_row.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_morph.dart';

/// While the photo panel is open each word row turns into one line,
/// "word — translation" (or the definition), and back when it closes.
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
    late AnimationController openness;
    setUp(() => openness = AnimationController(vsync: const TestVSync()));
    tearDown(() => openness.dispose());

    Widget host({double top = 0}) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.only(top: top),
              child: Align(
                alignment: Alignment.topCenter,
                child: WordRowMorph(
                  index: 0,
                  openness: openness,
                  full: const SizedBox(key: fullKey, height: 140),
                  line: (hideWord, hideDetail) => const CompactWordLine(
                      key: lineKey, index: 0, word: 'run', detail: 'бігти'),
                ),
              ),
            ),
          ),
        );

    double height(WidgetTester tester) => tester.getSize(find.byType(WordRowMorph)).height;

    testWidgets('follows the panel from the full row to its line and back', (tester) async {
      await tester.pumpWidget(host());
      expect(find.byKey(fullKey), findsOneWidget);
      expect(find.byKey(lineKey), findsNothing);
      expect(height(tester), 140);

      openness.value = 0.2;
      await tester.pump();
      expect(find.byKey(fullKey), findsOneWidget, reason: 'the full row fades out');
      expect(find.byKey(lineKey), findsOneWidget, reason: 'the line fades in');
      expect(height(tester), inExclusiveRange(56, 140), reason: 'the card glides');

      openness.value = 0.5;
      await tester.pump();
      expect(find.byKey(fullKey), findsNothing);
      final lineHeight = height(tester);
      expect(lineHeight, lessThan(70));

      openness.value = 0.8; // on to full-open: still the line
      await tester.pump();
      expect(height(tester), lineHeight);

      openness.value = 0.2;
      await tester.pump();
      expect(height(tester), inExclusiveRange(lineHeight, 140));
      openness.value = 0;
      await tester.pump();
      expect(find.byKey(fullKey), findsOneWidget);
      expect(find.byKey(lineKey), findsNothing);
      expect(height(tester), 140);
    });

    group('the texts fly', () {
      late TextEditingController word;
      late TextEditingController translation;
      setUp(() {
        word = TextEditingController(text: 'run');
        translation = TextEditingController(text: 'бігти');
      });
      tearDown(() {
        word.dispose();
        translation.dispose();
      });

      Widget flying({bool detail = true}) => MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: WordRowMorph(
                  index: 0,
                  openness: openness,
                  word: word,
                  detail: detail ? translation : null,
                  full: SyncedTextFieldRow(
                    leftController: word,
                    rightController: translation,
                    leftLabel: 'Word',
                    rightLabel: 'Translation',
                  ),
                  line: (hideWord, hideDetail) => CompactWordLine(
                      key: lineKey,
                      index: 0,
                      word: 'run',
                      detail: 'бігти',
                      hideWord: hideWord,
                      hideDetail: hideDetail),
                ),
              ),
            ),
          );

      Color? fieldColor(WidgetTester tester, TextEditingController c) => tester
          .widget<EditableText>(find.byWidgetPredicate(
              (w) => w is EditableText && w.controller == c))
          .style
          .color;
      CompactWordLine lineOf(WidgetTester tester) =>
          tester.widget<CompactWordLine>(find.byKey(lineKey));

      testWidgets('while moving, the texts are hidden in place and drawn flying',
          (tester) async {
        await tester.pumpWidget(flying());
        expect(fieldColor(tester, word)!.a, greaterThan(0));

        openness.value = 0.2;
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(fieldColor(tester, word)!.a, 0, reason: 'the word is flying');
        expect(fieldColor(tester, translation)!.a, 0, reason: 'so is the translation');
        expect(lineOf(tester).hideWord, isTrue);
        expect(lineOf(tester).hideDetail, isTrue);

        openness.value = 0.5;
        await tester.pump();
        expect(lineOf(tester).hideWord, isFalse, reason: 'landed: the line draws it');
        expect(lineOf(tester).hideDetail, isFalse);

        openness.value = 0.2;
        await tester.pump();
        expect(fieldColor(tester, word)!.a, 0, reason: 'flying back');
        openness.value = 0;
        await tester.pump();
        expect(fieldColor(tester, word)!.a, greaterThan(0), reason: 'back in its field');
        expect(fieldColor(tester, translation)!.a, greaterThan(0));
      });

      testWidgets('a detail without its field (a definition) only fades', (tester) async {
        await tester.pumpWidget(flying(detail: false));
        openness.value = 0.2;
        await tester.pump();
        expect(fieldColor(tester, translation)!.a, greaterThan(0));
        expect(lineOf(tester).hideWord, isTrue);
        expect(lineOf(tester).hideDetail, isFalse);
      });

      testWidgets('an empty word does not fly', (tester) async {
        word.text = '';
        await tester.pumpWidget(flying());
        openness.value = 0.2;
        await tester.pump();
        expect(lineOf(tester).hideWord, isFalse);
        expect(lineOf(tester).hideDetail, isTrue);
      });
    });

    testWidgets('closing again mid-morph keeps one field per controller in the end',
        (tester) async {
      final controller = TextEditingController(text: 'run');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WordRowMorph(
            index: 0,
            openness: openness,
            full: TextField(controller: controller, focusNode: focus),
            line: (hideWord, hideDetail) => const CompactWordLine(index: 0, word: 'run', detail: ''),
          ),
        ),
      ));
      openness.value = 0.15;
      await tester.pump();
      openness.value = 0;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(CompactWordLine), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    });

    testWidgets('built while open, it is the line at once', (tester) async {
      openness.value = 0.5;
      await tester.pumpWidget(host());
      expect(find.byKey(lineKey), findsOneWidget);
      expect(find.byKey(fullKey), findsNothing);
    });

    testWidgets('a rebuild that changes nothing does not animate', (tester) async {
      openness.value = 0.5;
      await tester.pumpWidget(host());
      await tester.pumpWidget(host());
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a row lower on the screen takes its turn later (the wave)', (tester) async {
      await tester.pumpWidget(host(top: 500));
      openness.value = 0.1;
      await tester.pump();
      expect(find.byKey(lineKey), findsNothing, reason: 'still waiting for its turn');
      openness.value = 0.4;
      await tester.pump();
      expect(find.byKey(lineKey), findsOneWidget);
    });

    testWidgets('a row at the top starts at once', (tester) async {
      await tester.pumpWidget(host());
      openness.value = 0.1;
      await tester.pump();
      expect(find.byKey(lineKey), findsOneWidget);
    });
  });
}
