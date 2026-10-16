import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/word_pair.dart';
import '../../core/providers.dart' show WordDetailMode;
import 'anki_export.dart';
import 'safe_file_name.dart';

/// The file formats the Share file menu offers. Anki stays the first and
/// keeps its own spec (`anki_export.dart`); the others follow the word detail
/// mode the same way: a column the mode hides is not written.
enum ShareFormat {
  anki('Anki', 'Text file for AnkiDroid', 'txt'),
  csv('CSV', 'Table for Excel, Numbers or Google Sheets', 'csv'),
  pdf('PDF', 'A printable word list', 'pdf'),
  quizlet('Quizlet', 'Paste into Quizlet\'s Import box', 'txt'),
  wordList('Word list', 'Plain text: word — translation', 'txt');

  const ShareFormat(this.title, this.subtitle, this.extension);

  final String title;
  final String subtitle;
  final String extension;

  /// The shared file is named after the collection (collections-screen
  /// AC-32): [name] made safe by [safeFileName], then the extension.
  String fileName(String name) => '${safeFileName(name)}.$extension';

  String get mimeType => switch (this) {
        ShareFormat.csv => 'text/csv',
        ShareFormat.pdf => 'application/pdf',
        _ => 'text/plain',
      };
}

/// The columns shown in [detail], in order, with their header names.
List<(String, String Function(WordPair))> _columns(WordDetailMode detail) => [
      ('Word', (p) => p.word),
      if (detail != WordDetailMode.definition)
        ('Translation', (p) => p.translation),
      if (detail != WordDetailMode.translation)
        ('Definition', (p) => p.definition),
    ];

/// Tabs and newlines inside a value would break a line-based format.
String _oneLine(String value) =>
    value.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();

/// RFC 4180: a field with a comma, quote or line break is quoted, quotes
/// doubled. CRLF line ends; a UTF-8 BOM so Excel reads Cyrillic correctly.
String generateCsvFile(
  List<WordPair> wordPairs, {
  WordDetailMode detail = WordDetailMode.translation,
}) {
  String field(String value) {
    final v = value.trim();
    return RegExp(r'[",\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;
  }

  final columns = _columns(detail);
  final buffer = StringBuffer('﻿');
  buffer.write('${columns.map((c) => c.$1).join(',')}\r\n');
  for (final pair in wordPairs) {
    if (pair.isEmpty) continue;
    buffer.write('${columns.map((c) => field(c.$2(pair))).join(',')}\r\n');
  }
  return buffer.toString();
}

/// Quizlet's import: term TAB definition, one card per line. The card's back
/// is the translation, the definition, or both joined by " — ".
String generateQuizletFile(
  List<WordPair> wordPairs, {
  WordDetailMode detail = WordDetailMode.translation,
}) {
  final buffer = StringBuffer();
  for (final pair in wordPairs) {
    if (pair.isEmpty) continue;
    final back = _columns(detail)
        .skip(1)
        .map((c) => _oneLine(c.$2(pair)))
        .where((v) => v.isNotEmpty)
        .join(' — ');
    buffer.writeln('${_oneLine(pair.word)}\t$back');
  }
  return buffer.toString();
}

/// A list to read: "word — translation", the definition indented below it.
String generateWordListFile(
  List<WordPair> wordPairs, {
  WordDetailMode detail = WordDetailMode.translation,
}) {
  final showTranslation = detail != WordDetailMode.definition;
  final showDefinition = detail != WordDetailMode.translation;
  final buffer = StringBuffer();
  for (final pair in wordPairs) {
    if (pair.isEmpty) continue;
    final translation = showTranslation ? _oneLine(pair.translation) : '';
    final definition = showDefinition ? _oneLine(pair.definition) : '';
    final word = _oneLine(pair.word);
    buffer.writeln(translation.isEmpty ? word : '$word — $translation');
    if (definition.isNotEmpty) buffer.writeln('    $definition');
  }
  return buffer.toString();
}

/// A table of the shown columns. [font] must cover Cyrillic: the PDF base
/// fonts are Latin-1 only, so the app ships Noto Sans (see [loadPdfFont]).
Future<Uint8List> generatePdfFile(
  List<WordPair> wordPairs, {
  required pw.Font font,
  WordDetailMode detail = WordDetailMode.translation,
  String title = 'English Vocabulary',
}) {
  final columns = _columns(detail);
  final rows = [
    for (final pair in wordPairs)
      if (!pair.isEmpty) [for (final c in columns) _oneLine(c.$2(pair))],
  ];
  final doc = pw.Document(title: title);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (_) => [
        pw.Header(
          level: 0,
          child: pw.Text(title, style: const pw.TextStyle(fontSize: 20)),
        ),
        pw.TableHelper.fromTextArray(
          headers: [for (final c in columns) c.$1],
          data: rows,
          headerStyle: const pw.TextStyle(fontSize: 12),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 11),
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        ),
      ],
    ),
  );
  return doc.save();
}

/// One file ready for the phone's share sheet.
class ShareFile {
  final String fileName;
  final String subject;
  final String mimeType;
  final List<int> bytes;

  const ShareFile({
    required this.fileName,
    required this.subject,
    required this.mimeType,
    required this.bytes,
  });
}

/// The file [format] makes of [wordPairs] for the collection called [name]
/// (collections-screen AC-32): its file name and the share's subject carry
/// the name; only the PDF also shows it inside, as its heading. [font] is
/// read only for the PDF.
Future<ShareFile> makeShareFile(
  ShareFormat format,
  List<WordPair> wordPairs, {
  required String name,
  WordDetailMode detail = WordDetailMode.translation,
  Future<pw.Font> Function() font = loadPdfFont,
}) async {
  final List<int> bytes = switch (format) {
    ShareFormat.anki =>
      utf8.encode(generateAnkiFile(wordPairs, detail: detail)),
    ShareFormat.csv => utf8.encode(generateCsvFile(wordPairs, detail: detail)),
    ShareFormat.quizlet =>
      utf8.encode(generateQuizletFile(wordPairs, detail: detail)),
    ShareFormat.wordList =>
      utf8.encode(generateWordListFile(wordPairs, detail: detail)),
    ShareFormat.pdf => await generatePdfFile(wordPairs,
        font: await font(), detail: detail, title: name),
  };
  return ShareFile(
    fileName: format.fileName(name),
    subject: name,
    mimeType: format.mimeType,
    bytes: bytes,
  );
}

Future<pw.Font> loadPdfFont() async =>
    pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
