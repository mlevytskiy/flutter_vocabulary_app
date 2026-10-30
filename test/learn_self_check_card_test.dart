import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/pronunciation_service.dart';
import 'package:flutter_vocabulary_app/core/theme/app_theme.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check_card.dart';

final now = DateTime(2026, 10, 30, 12);

WordPair row() => WordPair(word: 'apple', translation: 'яблуко', rowId: 'r1');

Widget host({
  required ThemeData theme,
  String side = 'uk',
  WordBox? box,
  bool afterMistake = false,
  String wordContext = '',
  bool contextByAi = false,
  ValueChanged<SelfRating>? onRated,
  ValueChanged<Accent>? onSpeak,
  bool disableAnimations = false,
}) =>
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
            size: const Size(393, 852), disableAnimations: disableAnimations),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelfCheckCard(
              row: row(),
              box: box,
              side: side,
              now: now,
              afterMistake: afterMistake,
              wordContext: wordContext,
              contextByAi: contextByAi,
              onSpeak: onSpeak ?? (_) {},
              onRated: onRated ?? (_) {},
            ),
          ),
        ),
      ),
    );

ButtonStyleButton button(WidgetTester tester, SelfRating r) =>
    tester.widget<ButtonStyleButton>(find.descendant(
        of: find.byKey(ValueKey('rate-${r.name}')),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));

Future<void> flip(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('self-check-card')));
  await tester.pumpAndSettle();
}

void main() {
  for (final spec in appThemes.where(
      (s) => s.id == AppThemeId.classic || s.id == AppThemeId.amberTerminal)) {
    final theme = spec.build();
    group(spec.name, () {
      testWidgets('Ukrainian front with Tap to flip; buttons off until flip',
          (tester) async {
        await tester.pumpWidget(host(theme: theme));
        expect(find.text('яблуко'), findsOneWidget);
        expect(find.text('apple'), findsNothing);
        expect(find.text('Tap to flip'), findsOneWidget);
        for (final r in SelfRating.values) {
          expect(button(tester, r).onPressed, isNull, reason: r.name);
        }
        await flip(tester);
        expect(find.byKey(const ValueKey('self-check-back')), findsOneWidget);
        expect(find.text('apple'), findsOneWidget);
        expect(find.text('яблуко'), findsOneWidget);
        expect(find.text('Tap to flip'), findsNothing);
        for (final r in SelfRating.values) {
          expect(button(tester, r).onPressed, isNotNull, reason: r.name);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('English front shows the word', (tester) async {
        await tester.pumpWidget(host(theme: theme, side: 'en'));
        expect(find.text('apple'), findsOneWidget);
        expect(find.text('яблуко'), findsNothing);
      });

      testWidgets('captions show the box each rating leads to', (tester) async {
        final box = WordBox()
          ..rowId = 'r1'
          ..word = 'apple'
          ..box = 3;
        await tester.pumpWidget(host(theme: theme, box: box));
        for (final r in SelfRating.values) {
          expect(
              find.descendant(
                  of: find.byKey(ValueKey('rate-${r.name}')),
                  matching: find.text(boxLabel(box, r, now))),
              findsOneWidget,
              reason: r.name);
        }
        expect(find.text('Box 1'), findsOneWidget); // I don't remember
        expect(find.text('Box 2'), findsOneWidget); // Hard
        expect(find.text('Box 3'), findsOneWidget); // Medium
        expect(find.text('Box 4'), findsOneWidget); // Easy
      });

      testWidgets('Easy after a mistake is captioned as Medium',
          (tester) async {
        final box = WordBox()..box = 3;
        await tester
            .pumpWidget(host(theme: theme, box: box, afterMistake: true));
        expect(
            find.descendant(
                of: find.byKey(const ValueKey('rate-easy')),
                matching: find.text('Box 3')),
            findsOneWidget);
      });

      testWidgets('a rating after the flip calls onRated once', (tester) async {
        final got = <SelfRating>[];
        await tester.pumpWidget(host(theme: theme, onRated: got.add));
        await tester.tap(find.text('Hard'));
        await tester.pump();
        expect(got, isEmpty);
        await flip(tester);
        await tester.tap(find.text('Hard'));
        await tester.tap(find.text('Easy'));
        await tester.pump();
        expect(got, [SelfRating.hard]);
      });

      testWidgets('each button reports its own rating', (tester) async {
        for (final (label, rating) in [
          ("I don't remember", SelfRating.dontRemember),
          ('Medium', SelfRating.medium),
          ('Easy', SelfRating.easy),
        ]) {
          SelfRating? got;
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(host(theme: theme, onRated: (r) => got = r));
          await flip(tester);
          await tester.tap(find.text(label));
          expect(got, rating);
        }
      });

      testWidgets('context from the source, in italic', (tester) async {
        await tester
            .pumpWidget(host(theme: theme, wordContext: 'An apple a day.'));
        expect(find.text('An apple a day.'), findsNothing);
        await flip(tester);
        final t = tester
            .widget<Text>(find.byKey(const ValueKey('self-check-context')));
        expect(t.data, 'An apple a day.');
        expect(t.style?.fontStyle, FontStyle.italic);
        expect(find.text('from the source'), findsOneWidget);
        expect(find.text('written by AI'), findsNothing);
      });

      testWidgets('context by AI has the sparkle in aiAccent', (tester) async {
        await tester.pumpWidget(host(
            theme: theme, wordContext: 'She ate an apple.', contextByAi: true));
        await flip(tester);
        expect(find.text('written by AI'), findsOneWidget);
        expect(find.text('from the source'), findsNothing);
        final ai = theme.extension<AppDecor>()!.aiAccent;
        final icon = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
        expect(icon.color, ai);
        expect(
            tester.widget<Text>(find.text('written by AI')).style?.color, ai);
      });

      testWidgets('no context line when the context is empty', (tester) async {
        await tester.pumpWidget(host(theme: theme, wordContext: '  '));
        await flip(tester);
        expect(find.byKey(const ValueKey('self-check-context')), findsNothing);
        expect(find.text('from the source'), findsNothing);
        expect(find.text('written by AI'), findsNothing);
      });

      testWidgets('buttons take the rating slots', (tester) async {
        await tester.pumpWidget(host(theme: theme));
        await flip(tester);
        final decor = theme.extension<AppDecor>()!;
        Color? colorOf(SelfRating r) {
          final s = button(tester, r).style!;
          return decor.picOutline
              ? s.foregroundColor?.resolve({})
              : s.backgroundColor?.resolve({});
        }

        expect(colorOf(SelfRating.dontRemember), decor.rateForgot);
        expect(colorOf(SelfRating.hard), decor.rateHard);
        expect(colorOf(SelfRating.medium), decor.rateMedium);
        expect(colorOf(SelfRating.easy), decor.rateEasy);
      });

      testWidgets('reduced motion flips at once', (tester) async {
        await tester.pumpWidget(host(theme: theme, disableAnimations: true));
        await tester.tap(find.byKey(const ValueKey('self-check-card')));
        await tester.pump();
        expect(find.byKey(const ValueKey('self-check-back')), findsOneWidget);
      });

      testWidgets('the speakers play the word', (tester) async {
        final heard = <Accent>[];
        await tester.pumpWidget(host(theme: theme, onSpeak: heard.add));
        await flip(tester);
        await tester.tap(find.byTooltip('UK pronunciation'));
        expect(heard, [Accent.uk]);
      });
    });
  }
}
