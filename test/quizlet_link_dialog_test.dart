import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/services/quizlet_link.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/quizlet_link_dialog.dart';

/// import-from-quizlet T9: the Quizlet link dialog (SCR-02) — ux-flows;
/// sad §6 F1; AC-01, AC-06.
void main() {
  late QuizletSetLink? result;
  late bool closed;

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    closed = false;
    result = null;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showQuizletLinkDialog(context);
            closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for a Quizlet set link (AC-01)', (tester) async {
    await openDialog(tester);
    expect(find.text('Import from Quizlet'), findsOneWidget);
    expect(find.byKey(const Key('quizlet-link')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text(QuizletImportMessages.pasteSetLink), findsNothing);
  });

  testWidgets(
      'Start with text holding no set link refuses and keeps the text (AC-06)',
      (tester) async {
    await openDialog(tester);
    const text = 'see https://example.com/123/words and quizlet.com/class/456';
    await tester.enterText(find.byKey(const Key('quizlet-link')), text);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text(QuizletImportMessages.pasteSetLink), findsOneWidget);
    expect(find.text(text), findsOneWidget, reason: 'the text is kept');
    expect(closed, isFalse);
  });

  testWidgets('Start with a set link returns it and closes', (tester) async {
    await openDialog(tester);
    await tester.enterText(find.byKey(const Key('quizlet-link')),
        'Check out this set: https://quizlet.com/ar/123456/animals-flash-cards/?x=1');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.text('Import from Quizlet'), findsNothing);
    expect(
        result,
        const QuizletSetLink(
            setId: '123456',
            plainUrl: 'https://quizlet.com/123456/animals-flash-cards/'));
  });

  testWidgets('closing returns null', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('editing the text clears the refusal', (tester) async {
    await openDialog(tester);
    await tester.enterText(find.byKey(const Key('quizlet-link')), 'words');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text(QuizletImportMessages.pasteSetLink), findsOneWidget);
    await tester.enterText(find.byKey(const Key('quizlet-link')), 'words.');
    await tester.pumpAndSettle();
    expect(find.text(QuizletImportMessages.pasteSetLink), findsNothing);
  });
}
