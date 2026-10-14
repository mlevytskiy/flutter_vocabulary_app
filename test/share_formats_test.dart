import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/words_table/share_formats.dart';

/// The Share file formats besides Anki (anki_export_test.dart): each skips
/// blank rows and writes only the columns the word detail mode shows.
void main() {
  final words = [
    WordPair(word: 'claim', translation: 'заява', definition: 'to ask for'),
    WordPair(),
    WordPair(word: 'say "hi", ok', translation: 'привіт\tвсім'),
  ];

  test('CSV: BOM, header, CRLF, quoted fields with commas and quotes', () {
    expect(
      generateCsvFile(words),
      '﻿Word,Translation\r\n'
      'claim,заява\r\n'
      '"say ""hi"", ok",привіт\tвсім\r\n',
    );
    expect(
      generateCsvFile(words, detail: WordDetailMode.both).split('\r\n')[0],
      '﻿Word,Translation,Definition',
    );
    expect(
      generateCsvFile(words, detail: WordDetailMode.definition)
          .split('\r\n')[1],
      'claim,to ask for',
    );
  });

  test('Quizlet: term TAB back, tabs inside a field become a space', () {
    expect(generateQuizletFile(words),
        'claim\tзаява\nsay "hi", ok\tпривіт всім\n');
    expect(generateQuizletFile(words, detail: WordDetailMode.both),
        'claim\tзаява — to ask for\nsay "hi", ok\tпривіт всім\n');
  });

  test('Word list: word — translation, definition indented below', () {
    expect(generateWordListFile(words, detail: WordDetailMode.both),
        'claim — заява\n    to ask for\nsay "hi", ok — привіт всім\n');
    expect(generateWordListFile(words, detail: WordDetailMode.definition),
        'claim\n    to ask for\nsay "hi", ok\n');
  });

  test('PDF: a valid document with the Cyrillic font embedded', () async {
    final font = pw.Font.ttf(ByteData.sublistView(
        File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync()));
    final bytes = await generatePdfFile(words, font: font);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes), contains('NotoSans'));
  });

  test('file names never collide between the .txt formats', () {
    final names = {for (final f in ShareFormat.values) f.fileName('2026-10-14')};
    expect(names, hasLength(ShareFormat.values.length));
    expect(ShareFormat.anki.fileName('2026-10-14'), 'vocabulary_2026-10-14.txt');
  });
}
