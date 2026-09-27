import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/words_table/anki_export.dart';

/// The expected bytes here are the spec in vocab-photo-api/README.md
/// § "AnkiDroid file format". The Worker's download is diffed against the same
/// text (task-07 AC-3), so this test and that diff pin both implementations to
/// one shape. definition-mode (ADR-0005) moved it to fixed columns — word,
/// translation, definition, tags — with the column the mode hides left empty.
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
      '#tags column:4\n'
      'receipt\tквитанція\t\t\n'
      'shelf\tполиця\t\t\n'
      'cup\tчашка\t\t\n'
      'tea\tчай\t\t\n'
      'book\tкнига\t\t\n',
    );
  });

  test('a blank row (the trailing empty row) is never written', () {
    final file = generateAnkiFile([
      WordPair(word: 'tea', translation: 'чай'),
      WordPair(),
      WordPair(word: '  ', translation: ''),
    ]);

    expect(file.split('\n').where((l) => l.startsWith('\t')), isEmpty);
    expect(file, endsWith('tea\tчай\t\t\n'));
    expect('\n'.allMatches(file).length, 4);
  });

  test('markup is escaped and tabs/newlines collapse to one space', () {
    final file = generateAnkiFile([
      WordPair(
          word: 'a <b>&</b>\tword\nhere',
          translation: 'x\r\ny',
          definition: 'one\ttwo\n<i>three</i>'),
    ], detail: WordDetailMode.both);

    expect(
      file,
      endsWith(
          'a &lt;b&gt;&amp;&lt;/b&gt; word here\tx y\tone two &lt;i&gt;three&lt;/i&gt;\t\n'),
    );
  });

  group('fixed columns per mode (ADR-0005, spec AC-15)', () {
    final pairs = [
      WordPair(word: 'claim', translation: 'заява', definition: 'to ask for'),
      WordPair(word: 'gated', definition: 'having a gate'),
    ];

    test('translation mode leaves the definition column empty', () {
      expect(
        generateAnkiFile(pairs, detail: WordDetailMode.translation),
        '#separator:tab\n#html:true\n#tags column:4\n'
        'claim\tзаява\t\t\n'
        'gated\t\t\t\n',
      );
    });

    test('definition mode leaves the translation column empty', () {
      expect(
        generateAnkiFile(pairs, detail: WordDetailMode.definition),
        '#separator:tab\n#html:true\n#tags column:4\n'
        'claim\t\tto ask for\t\n'
        'gated\t\thaving a gate\t\n',
      );
    });

    test('both fills both, matching the README example byte for byte', () {
      expect(
        generateAnkiFile([pairs.first], detail: WordDetailMode.both),
        '#separator:tab\n#html:true\n#tags column:4\n'
        'claim\tзаява\tto ask for\t\n',
      );
    });
  });
}
