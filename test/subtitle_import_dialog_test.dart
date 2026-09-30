import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/import_loading_dialog.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/subtitle_import_dialog.dart';

/// words-from-subtitles T10: the import dialog (SCR-02) and the loading
/// dialog (SCR-04) — ux-flows; sad §6 F1; AC-01, AC-09, AC-11.
void main() {
  const initial = SubtitleImportPrefs(
    purpose: ImportPurpose.understandFilm,
    level: EnglishLevel.b2,
    maximum: 20,
    updateEachImport: true,
    model: SubtitleModel.sonnet5,
  );
  final srt = XFile.fromData(
    Uint8List.fromList(utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nHello.\n')),
    name: 'film.srt',
    path: 'film.srt', // on IO an XFile's name comes from its path
  );

  late SubtitleImportRequest? result;
  late bool closed;

  Future<void> openDialog(WidgetTester tester, {required Future<XFile?> Function() pickFile}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showSubtitleImportDialog(context, initial: initial, pickFile: pickFile);
            closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  TextButton startButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Start'));

  testWidgets('opens with the values from Settings and asks for a file (AC-01)', (tester) async {
    await openDialog(tester, pickFile: () async => null);
    expect(find.text('Words from subtitles'), findsOneWidget);
    expect(tester.widget<RadioGroup<ImportPurpose>>(find.byType(RadioGroup<ImportPurpose>)).groupValue,
        ImportPurpose.understandFilm);
    expect(tester.widget<DropdownButton<EnglishLevel>>(find.byType(DropdownButton<EnglishLevel>)).value, EnglishLevel.b2);
    expect(find.widgetWithText(TextField, '20'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('No file chosen'), findsOneWidget);
    expect(startButton(tester).onPressed, isNull, reason: 'Start waits for a file');
  });

  testWidgets('a cancelled pick leaves the dialog as it was', (tester) async {
    await openDialog(tester, pickFile: () async => null);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.text('No file chosen'), findsOneWidget);
    expect(startButton(tester).onPressed, isNull);
  });

  testWidgets('Start returns the file and the chosen values; the dialog closes', (tester) async {
    await openDialog(tester, pickFile: () async => srt);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.text('film.srt'), findsOneWidget);

    await tester.tap(find.text('Frequent words for the future'));
    await tester.tap(find.byType(DropdownButton<EnglishLevel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C1').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import-maximum')), '30');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.text('Words from subtitles'), findsNothing);
    expect(result!.fileName, 'film.srt');
    expect(result!.extension, 'srt');
    expect(utf8.decode(result!.bytes), contains('Hello.'));
    expect(result!.purpose, ImportPurpose.frequentWords);
    expect(result!.level, EnglishLevel.c1);
    expect(result!.maximum, 30);
  });

  testWidgets('a file over 1 MB is refused with the largest size named, and Start stays off (AC-11)', (tester) async {
    final big = XFile.fromData(Uint8List(1048577), name: 'huge.srt', path: 'huge.srt');
    await openDialog(tester, pickFile: () async => big);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.text('This file is too large. The largest file accepted is 1 MB.'), findsOneWidget);
    expect(startButton(tester).onPressed, isNull);
  });

  testWidgets('exactly 1 MB is accepted', (tester) async {
    final edge = XFile.fromData(Uint8List(1048576), name: 'edge.vtt', path: 'edge.vtt');
    await openDialog(tester, pickFile: () async => edge);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('too large'), findsNothing);
    expect(startButton(tester).onPressed, isNotNull);
  });

  testWidgets('a maximum outside 1–100 says so and keeps Start off (AC-09)', (tester) async {
    await openDialog(tester, pickFile: () async => srt);
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    for (final value in ['0', '101', '']) {
      await tester.enterText(find.byKey(const Key('import-maximum')), value);
      await tester.pumpAndSettle();
      expect(find.text('The maximum must be from 1 to 100'), findsOneWidget, reason: value);
      expect(startButton(tester).onPressed, isNull, reason: value);
    }
    await tester.enterText(find.byKey(const Key('import-maximum')), '1');
    await tester.pumpAndSettle();
    expect(startButton(tester).onPressed, isNotNull);
  });

  testWidgets('Cancel closes with nothing', (tester) async {
    await openDialog(tester, pickFile: () async => srt);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('the loading dialog cannot be dismissed by the barrier or back (SCR-04)', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        ctx = context;
        return const SizedBox.expand();
      }),
    ));
    showImportLoadingDialog(ctx);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Picking words from the subtitles…'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5)); // the barrier
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Picking words from the subtitles…'), findsOneWidget);

    await tester.binding.handlePopRoute(); // Android back
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Picking words from the subtitles…'), findsOneWidget);

    closeImportLoadingDialog(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Picking words from the subtitles…'), findsNothing);
  });
}
