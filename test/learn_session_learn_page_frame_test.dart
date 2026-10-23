import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/theme/app_theme.dart';
import 'package:flutter_vocabulary_app/features/learn/session/exercise_page.dart';
import 'package:flutter_vocabulary_app/features/learn/session/learn_page_frame.dart';

Widget host(
  PageAnswer answer, {
  PageVerdict? verdict,
  ThemeData? theme,
  void Function(Map<String, bool>)? onResult,
  VoidCallback? onContinue,
}) =>
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: LearnPageFrame(
          step: 2,
          stepProgress: 0.5,
          page: 3,
          total: 12,
          chip: 'Quiz',
          body: const Text('Pick the translation of cat'),
          answer: answer,
          verdict: verdict,
          onContinue: onContinue ?? () {},
          onClose: () {},
          onResult: onResult ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('shows N / M, chip, body and a disabled Check until ready',
      (tester) async {
    final answer = PageAnswer();
    await tester.pumpWidget(host(answer));
    expect(find.text('3 / 12'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Pick the translation of cat'), findsOneWidget);
    expect(find.byKey(const ValueKey('step-1')), findsOneWidget);
    FilledButton check() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Check'));
    expect(check().onPressed, isNull);
    answer.ready(() async => {'a': true});
    await tester.pump();
    expect(check().onPressed, isNotNull);
    answer.notReady();
    await tester.pump();
    expect(check().onPressed, isNull);
  });

  testWidgets('Check passes the results to onResult', (tester) async {
    final answer = PageAnswer();
    Map<String, bool>? got;
    await tester.pumpWidget(host(answer, onResult: (r) => got = r));
    answer.ready(() async => {'a': true, 'b': false});
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(got, {'a': true, 'b': false});
  });

  testWidgets('done() skips Check and reports at once', (tester) async {
    final answer = PageAnswer();
    Map<String, bool>? got;
    await tester.pumpWidget(host(answer, onResult: (r) => got = r));
    answer.done({'a': false});
    await tester.pump();
    await tester.pump();
    expect(find.text('Check'), findsNothing);
    expect(got, {'a': false});
  });

  testWidgets('verdict bar shows texts and Continue', (tester) async {
    var continued = false;
    await tester.pumpWidget(host(
      PageAnswer(),
      verdict: const PageVerdict(
          right: false, word: 'cat', translation: 'кіт', rightAnswer: 'кіт'),
      onContinue: () => continued = true,
    ));
    await tester.pumpAndSettle();
    expect(find.text('✗ Not quite'), findsOneWidget);
    expect(find.text('cat — кіт'), findsOneWidget);
    expect(find.text('Check'), findsNothing);
    await tester.tap(find.text('Continue'));
    expect(continued, isTrue);
    await tester.pumpWidget(host(PageAnswer(),
        verdict:
            const PageVerdict(right: true, word: 'cat', translation: 'кіт')));
    await tester.pumpAndSettle();
    expect(find.text('✓ Right'), findsOneWidget);
  });

  for (final spec in appThemes) {
    testWidgets('no overflow in ${spec.name} at 393x852, text scale 1.3',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final verdict in [
        null,
        const PageVerdict(
            right: false,
            word: 'extraordinary',
            translation: 'надзвичайний, незвичайний, виняткову',
            rightAnswer: 'надзвичайний'),
      ]) {
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(
              size: Size(393, 852), textScaler: TextScaler.linear(1.3)),
          child: host(PageAnswer()..ready(() async => {}),
              verdict: verdict, theme: spec.build()),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: spec.name);
      }
    });
  }
}
