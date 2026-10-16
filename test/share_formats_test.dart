import 'dart:convert';
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

  // collections-screen T24: every format is named after the collection and
  // carries it as the subject; only the PDF shows it inside (AC-32).
  group('named after the collection (T24)', () {
    const name = 'Unit 3: phrasal verbs?';
    final font = pw.Font.ttf(ByteData.sublistView(
        File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync()));

    for (final format in ShareFormat.values) {
      test('${format.title}: file name and subject carry the name', () async {
        final file = await makeShareFile(format, words,
            name: name, font: () async => font);
        expect(file.fileName, 'Unit 3- phrasal verbs-.${format.extension}');
        expect(file.subject, name);
        expect(file.mimeType, format.mimeType);
        if (format != ShareFormat.pdf) {
          expect(utf8.decode(file.bytes), isNot(contains('Unit 3')));
        }
      });
    }

    test('a default name keeps its date and swaps the colon', () async {
      final file = await makeShareFile(ShareFormat.csv, words,
          name: '16.10.2026 14:30', font: () async => font);
      expect(file.fileName, '16.10.2026 14-30.csv');
      expect(file.subject, '16.10.2026 14:30');
    });

    test('nothing left falls back to "collection"', () async {
      final file = await makeShareFile(ShareFormat.wordList, words,
          name: '???', font: () async => font);
      expect(file.fileName, '---.txt');
      final blank = await makeShareFile(ShareFormat.wordList, words,
          name: '   ', font: () async => font);
      expect(blank.fileName, 'collection.txt');
    });

    test('the PDF shows the name as its heading', () async {
      final named = await makeShareFile(ShareFormat.pdf, words,
          name: name, font: () async => font);
      final other = await makeShareFile(ShareFormat.pdf, words,
          name: 'Another one', font: () async => font);
      expect(String.fromCharCodes(named.bytes.take(5)), '%PDF-');
      // The heading is drawn: the page differs only by the name.
      expect(named.bytes, isNot(equals(other.bytes)));
    });
  });
}
