import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/features/words_table/anki_export.dart';

/// The expected bytes here are the spec in vocab-photo-api/README.md
/// § "AnkiDroid file format". The Worker's download is diffed against the same
/// text (task-07 AC-3), so this test and that diff pin both implementations to
/// one shape.
void main() {
  test('five words: three header lines, five records, trailing tab, LF', () {
    final file = generateAnkiFile([
      WordPair(word: 'receipt', translation: 'квитанція'),
      WordPair(word: 'shelf', translation: 'полиця'),
      WordPair(word: 'cup', translation: 'чашка'),
      WordPair(word: 'tea', translation: 'чай'),
      WordPair(word: 'book', translation: 'книга'),
    ]);

    expect(
      file,
      '#separator:tab\n'
      '#html:true\n'
      '#tags column:3\n'
      'receipt\tквитанція\t\n'
      'shelf\tполиця\t\n'
      'cup\tчашка\t\n'
      'tea\tчай\t\n'
      'book\tкнига\t\n',
    );
  });

  test('a blank row (the trailing empty row) is never written', () {
    final file = generateAnkiFile([
      WordPair(word: 'tea', translation: 'чай'),
      WordPair(),
      WordPair(word: '  ', translation: ''),
    ]);

    expect(file.split('\n').where((l) => l.startsWith('\t')), isEmpty);
    expect(file, endsWith('tea\tчай\t\n'));
    expect('\n'.allMatches(file).length, 4);
  });

  test('markup is escaped and tabs/newlines collapse to one space', () {
    final file = generateAnkiFile([
      WordPair(word: 'a <b>&</b>\tword\nhere', translation: 'x\r\ny'),
    ]);

    expect(
      file,
      endsWith('a &lt;b&gt;&amp;&lt;/b&gt; word here\tx y\t\n'),
    );
  });
}
