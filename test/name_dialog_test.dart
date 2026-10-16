import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/collections/name_dialog.dart';

/// SCR-02 NameDialog (collections-screen T14; AC-02, AC-03).
void main() {
  const invalidMessage = 'A name must be 1 to 60 characters on one line';

  /// Pumps a button that opens the dialog and records what it resolved with.
  Future<List<String?>> open(
    WidgetTester tester,
    NameDialogMode mode, {
    String initial = '',
  }) async {
    final results = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(
                await showNameDialog(context, mode: mode, initial: initial)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  TextField field(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  testWidgets('rename collection: title, Save, initial name all selected',
      (tester) async {
    await open(tester, NameDialogMode.renameCollection,
        initial: '16.10.2026 14:30');
    expect(find.text('Rename collection'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    final controller = field(tester).controller!;
    expect(controller.text, '16.10.2026 14:30');
    expect(controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 16));
  });

  testWidgets('rename folder: title and Save', (tester) async {
    await open(tester, NameDialogMode.renameFolder, initial: 'Verbs');
    expect(find.text('Rename folder'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('new folder: title, empty field, Create', (tester) async {
    await open(tester, NameDialogMode.newFolder);
    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(field(tester).controller!.text, isEmpty);
  });

  for (final bad in ['', '   ', 'x' * 61, 'a b']) {
    testWidgets('invalid ${bad.length}-char name keeps the dialog open',
        (tester) async {
      final results =
          await open(tester, NameDialogMode.renameCollection, initial: 'Old');
      await tester.enterText(find.byType(TextField), bad);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(invalidMessage), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(results, isEmpty);
    });
  }

  testWidgets('valid name returns it as typed (no trimming)', (tester) async {
    final results =
        await open(tester, NameDialogMode.renameCollection, initial: 'Old');
    await tester.enterText(find.byType(TextField), ' Phrasal verbs');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(results, [' Phrasal verbs']);
  });

  testWidgets('a 60-character name is accepted', (tester) async {
    final results = await open(tester, NameDialogMode.newFolder);
    await tester.enterText(find.byType(TextField), 'y' * 60);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(results, ['y' * 60]);
  });

  testWidgets('Cancel returns null', (tester) async {
    final results =
        await open(tester, NameDialogMode.renameFolder, initial: 'Verbs');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(results, [null]);
  });

  testWidgets('a newline cannot be typed', (tester) async {
    await open(tester, NameDialogMode.renameCollection, initial: 'Old');
    final f = field(tester);
    expect(f.maxLines, 1);
    await tester.enterText(find.byType(TextField), 'a\nb\rc');
    await tester.pump();
    expect(f.controller!.text, 'abc');
  });
}
